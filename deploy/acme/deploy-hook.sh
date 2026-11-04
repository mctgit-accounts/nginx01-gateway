#!/usr/bin/env bash
# certbot --deploy-hook: install the issued cert where nginx expects it, reload.
# Runs as root on nginx01-gateway.
set -euo pipefail
lineage="${RENEWED_LINEAGE:-/etc/letsencrypt/live/mankatotech-wildcard}"
dst=/etc/nginx/ssl/mankatotech

if [ ! -r "$lineage/fullchain.pem" ] || [ ! -r "$lineage/privkey.pem" ]; then
    echo "deploy-hook: certificate not found under $lineage" >&2
    exit 1
fi
if ! openssl x509 -in "$lineage/fullchain.pem" -noout -checkend 86400 >/dev/null 2>&1; then
    echo "deploy-hook: certificate invalid or expiring within 24 h; refusing" >&2
    exit 1
fi

install -d "$dst"
install -m 0644 "$lineage/fullchain.pem" "$dst/fullchain.pem"
install -m 0600 "$lineage/privkey.pem"   "$dst/privkey.pem"

nginx -t
systemctl reload nginx
echo "deploy-hook: installed $lineage -> $dst; nginx reloaded"
