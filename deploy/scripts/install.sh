#!/usr/bin/env bash
# Deploy the nginx gateway config set on this host. Run as root.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"   # deploy/

install -d /etc/nginx/snippets /etc/nginx/templates /etc/nginx/conf.d \
           /etc/nginx/ssl/mankatotech /var/log/nginx

# conf.d loads alphabetically — the log format must be defined before use.
rm -f /etc/nginx/conf.d/00-map.conf /etc/nginx/conf.d/00-limits.conf /etc/nginx/conf.d/00-default.conf
install -m 0644 "$here/nginx/log-format.conf"            /etc/nginx/conf.d/00-log-format.conf
install -m 0644 "$here/nginx/conf.d/10-map.conf"         /etc/nginx/conf.d/10-map.conf
install -m 0644 "$here/nginx/conf.d/10-limits.conf"      /etc/nginx/conf.d/10-limits.conf
install -m 0644 "$here/nginx/conf.d/10-default.conf"     /etc/nginx/conf.d/10-default.conf
install -m 0644 "$here/nginx/snippets/proxy-common.conf" /etc/nginx/snippets/proxy-common.conf
install -m 0644 "$here/nginx/snippets/tls-common.conf"   /etc/nginx/snippets/tls-common.conf
install -m 0644 "$here/nginx/templates/app.vhost.template" /etc/nginx/templates/app.vhost.template
install -m 0755 "$here/scripts/add-app.sh"               /usr/local/bin/add-app

# Drop the stock default site so only our catch-all answers.
rm -f /etc/nginx/sites-enabled/default

# Placeholder self-signed cert so nginx can start before ACME has run.
if [ ! -f /etc/nginx/ssl/mankatotech/fullchain.pem ]; then
    openssl req -x509 -newkey rsa:2048 -nodes -days 30 \
        -keyout /etc/nginx/ssl/mankatotech/privkey.pem \
        -out /etc/nginx/ssl/mankatotech/fullchain.pem \
        -subj "/CN=*.mankatotech.com" >/dev/null 2>&1
    echo "install.sh: installed a PLACEHOLDER self-signed cert (ACME will replace it)"
fi

nginx -t
systemctl reload nginx
echo "install.sh: done"
