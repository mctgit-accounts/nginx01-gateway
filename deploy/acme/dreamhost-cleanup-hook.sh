#!/usr/bin/env bash
# certbot --manual-cleanup-hook (DNS-01, DreamHost API).
#
# Removes the challenge TXT record published by the auth hook. Tolerant: a
# missing record or a transient API failure logs a warning but does not fail
# the renewal (stale records are cleared by the auth hook on the next run).
#
# Environment: CERTBOT_DOMAIN, CERTBOT_VALIDATION (from certbot);
# DREAMHOST_KEY_FILE, DREAMHOST_API_URL, MCT_ACME_CLEANUP_SLEEP (default 5).
set -euo pipefail

key_file="${DREAMHOST_KEY_FILE:-/etc/mct-acme/dreamhost-dns.key}"
api_url="${DREAMHOST_API_URL:-https://api.dreamhost.com/}"
sleep_s="${MCT_ACME_CLEANUP_SLEEP:-5}"

: "${CERTBOT_DOMAIN:?certbot must provide CERTBOT_DOMAIN}"
: "${CERTBOT_VALIDATION:?certbot must provide CERTBOT_VALIDATION}"
record="_acme-challenge.${CERTBOT_DOMAIN}"

if [ ! -r "$key_file" ]; then
    echo "dreamhost-cleanup-hook: cannot read API key file: $key_file" >&2
    exit 1
fi
key="$(tr -d '\r\n' < "$key_file")"

for _attempt in 1 2 3; do
    if { curl -fsS -G "$api_url" \
            --data-urlencode "key=$key" \
            --data-urlencode "cmd=dns-remove_record" \
            --data-urlencode "format=json" \
            --data-urlencode "record=$record" \
            --data-urlencode "type=TXT" \
            --data-urlencode "value=$CERTBOT_VALIDATION" \
        | python3 -c '
import json, sys
r = json.load(sys.stdin)
sys.exit(0 if r.get("result") == "success" else 1)
'; } 2>/dev/null; then
        echo "dreamhost-cleanup-hook: removed $record (TXT)"
        exit 0
    fi
    sleep "$sleep_s"
done

echo "dreamhost-cleanup-hook: warning: could not remove TXT record for $record (harmless; cleaned by the next auth run)" >&2
exit 0
