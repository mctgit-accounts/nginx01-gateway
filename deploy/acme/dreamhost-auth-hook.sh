#!/usr/bin/env bash
# certbot --manual-auth-hook (DNS-01, DreamHost API).
#
# Publishes the challenge TXT record `_acme-challenge.<CERTBOT_DOMAIN>` via the
# DreamHost API, clears stale values for the same name, then waits until all
# DreamHost authoritative nameservers serve the record *consistently* before
# letting certbot engage the ACME service. Exits non-zero on any failure (fail
# closed).
#
# Why the settle window: DreamHost's nameservers run behind multiple backends
# that publish adds/deletes with a per-server lag (measured 2026-11-02: ~90 s
# to ~6 min for adds; deletes lag far longer). A single "all three visible"
# observation can race with stale records still draining, and Let's Encrypt's
# secondary validation then sees an old value. Requiring the record to stay
# visible across all three servers for a settle period makes that race very
# unlikely.
#
# Configuration (environment):
#   DREAMHOST_KEY_FILE   scoped API key file (default /etc/mct-acme/dreamhost-dns.key)
#   DREAMHOST_API_URL    API base (default https://api.dreamhost.com/)
#   MCT_ACME_PROPAGATION_TIMEOUT   seconds to wait for nameserver visibility
#                                  (default 1800; 0 skips the wait)
#   MCT_ACME_SETTLE_SECONDS        keep the record visible on all nameservers
#                                  for this long before returning (default 120;
#                                  0 disables)
#   MCT_ACME_PROPAGATION_INTERVAL  seconds between visibility checks (default 10)
#   MCT_ACME_NAMESERVERS           space-separated authoritative servers
#                                  (default ns1..ns3.dreamhost.com)
set -euo pipefail

key_file="${DREAMHOST_KEY_FILE:-/etc/mct-acme/dreamhost-dns.key}"
api_url="${DREAMHOST_API_URL:-https://api.dreamhost.com/}"
timeout_s="${MCT_ACME_PROPAGATION_TIMEOUT:-1800}"
settle_s="${MCT_ACME_SETTLE_SECONDS:-120}"
interval_s="${MCT_ACME_PROPAGATION_INTERVAL:-10}"
read -r -a nameservers <<< "${MCT_ACME_NAMESERVERS:-ns1.dreamhost.com ns2.dreamhost.com ns3.dreamhost.com}"

: "${CERTBOT_DOMAIN:?certbot must provide CERTBOT_DOMAIN}"
: "${CERTBOT_VALIDATION:?certbot must provide CERTBOT_VALIDATION}"
record="_acme-challenge.${CERTBOT_DOMAIN}"

if [ ! -r "$key_file" ]; then
    echo "dreamhost-auth-hook: cannot read API key file: $key_file" >&2
    exit 1
fi
key="$(tr -d '\r\n' < "$key_file")"
if [ -z "$key" ]; then
    echo "dreamhost-auth-hook: API key file is empty: $key_file" >&2
    exit 1
fi

_dh_api() { # _dh_api <cmd> [param=value ...] — DreamHost API call, raw JSON
    local cmd="$1"; shift
    local args=(-fsS -G "$api_url"
        --data-urlencode "key=$key"
        --data-urlencode "cmd=$cmd"
        --data-urlencode "format=json")
    local p
    for p in "$@"; do args+=(--data-urlencode "$p"); done
    curl "${args[@]}"
}

_dh_data() { # stdin: API JSON — prints the data field as JSON, fails on error
    python3 -c '
import json, sys
r = json.load(sys.stdin)
if r.get("result") != "success":
    sys.stderr.write("dreamhost api error: %s\n" % r.get("data"))
    sys.exit(1)
print(json.dumps(r.get("data")))
'
}

_dh_txt_values() { # prints current TXT values for $record, one per line
    _dh_api dns-list_records | _dh_data | python3 -c '
import json, sys
name = sys.argv[1]
for item in json.load(sys.stdin):
    if item.get("record") == name and item.get("type") == "TXT":
        print(item.get("value"))
' "$record"
}

have=0
while IFS= read -r value; do
    [ -n "$value" ] || continue
    if [ "$value" = "$CERTBOT_VALIDATION" ]; then
        have=1
    else
        _dh_api dns-remove_record "record=$record" type=TXT "value=$value" | _dh_data >/dev/null
        echo "dreamhost-auth-hook: removed stale TXT value for $record"
    fi
done <<< "$(_dh_txt_values)"

if [ "$have" -eq 0 ]; then
    _dh_api dns-add_record "record=$record" type=TXT \
        "value=$CERTBOT_VALIDATION" comment="mct-acme certbot" | _dh_data >/dev/null
    echo "dreamhost-auth-hook: added $record (TXT)"
else
    echo "dreamhost-auth-hook: $record already present"
fi

if [ "$timeout_s" -gt 0 ]; then
    command -v dig >/dev/null || { echo "dreamhost-auth-hook: dig not found (install dnsutils)" >&2; exit 1; }
    echo "dreamhost-auth-hook: waiting for TXT visibility on ${nameservers[*]} (timeout ${timeout_s}s, settle ${settle_s}s)"
    deadline=$(( $(date +%s) + timeout_s ))
    visible_since=""
    while :; do
        visible=1
        for ns in "${nameservers[@]}"; do
            if ! dig +short TXT "$record" "@$ns" 2>/dev/null | tr -d '"' | grep -qxF "$CERTBOT_VALIDATION"; then
                visible=0
                break
            fi
        done
        if [ "$visible" -eq 1 ]; then
            if [ -z "$visible_since" ]; then
                visible_since=$(date +%s)
                echo "dreamhost-auth-hook: TXT visible on all nameservers; settling for ${settle_s}s"
            fi
            if [ $(( $(date +%s) - visible_since )) -ge "$settle_s" ]; then
                break
            fi
        else
            visible_since=""
        fi
        if [ "$(date +%s)" -ge "$deadline" ]; then
            echo "dreamhost-auth-hook: TXT not consistently visible on all nameservers after ${timeout_s}s" >&2
            exit 1
        fi
        sleep "$interval_s"
    done
    echo "dreamhost-auth-hook: TXT visible and stable on all nameservers"
fi
