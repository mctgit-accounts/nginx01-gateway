#!/usr/bin/env bash
# Issue (or renew) the wildcard gateway certificate via ACME DNS-01 (DreamHost).
# Run as root on nginx01-gateway.
#
#   ACME_EMAIL=ops@example.net ./issue.sh --staging     # test lineage only
#   ACME_EMAIL=ops@example.net ./issue.sh --production  # real cert + nginx reload
#
# Requires certbot and the scoped DreamHost key at /etc/mct-acme/dreamhost-dns.key
# (see dreamhost-auth-hook.sh). Requests one cert for mankatotech.com +
# *.mankatotech.com (covers app1..appN and any future host).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"

mode="${1:-}"
case "$mode" in
    --staging|--production) ;;
    *) echo "usage: $0 --staging|--production" >&2; exit 2 ;;
esac

if [ "$(id -u)" -ne 0 ]; then
    echo "issue.sh: run as root (certbot + deploy hook need it)" >&2
    exit 1
fi

: "${ACME_EMAIL:?export ACME_EMAIL=<approved ACME contact> first}"

certbot_bin="${CERTBOT:-certbot}"
command -v "$certbot_bin" >/dev/null || { echo "issue.sh: certbot not found" >&2; exit 1; }

flags=()
case "$mode" in
    --staging)
        flags+=(--staging --cert-name mankatotech-wildcard-staging)
        ;;
    --production)
        flags+=(--cert-name mankatotech-wildcard --deploy-hook "$here/deploy-hook.sh")
        ;;
esac

if "$certbot_bin" --help all 2>/dev/null | grep -q -- "--manual-public-ip-logging-ok"; then
    flags+=(--manual-public-ip-logging-ok)
fi

"$certbot_bin" certonly --non-interactive --agree-tos --email "$ACME_EMAIL" \
    --manual --preferred-challenges dns \
    --key-type rsa --rsa-key-size 3072 \
    --manual-auth-hook "$here/dreamhost-auth-hook.sh" \
    --manual-cleanup-hook "$here/dreamhost-cleanup-hook.sh" \
    -d mankatotech.com -d '*.mankatotech.com' \
    "${flags[@]}"

echo "issue.sh: ${mode#--} issuance complete (lineage per --cert-name above)"
