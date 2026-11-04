#!/usr/bin/env bash
# add-app <app> <host:port> [fqdn]
#   app     short slug, e.g. app6 (used for the log filenames)
#   backend backend host:port on the internal network, e.g. 10.100.200.20:8080
#   fqdn    optional FQDN to serve (default <app>.mankatotech.com)
#
# Renders a vhost from the template, validates, and reloads nginx.
set -euo pipefail

app="${1:?usage: add-app <app> <host:port> [fqdn]}"
backend="${2:?usage: add-app <app> <host:port> [fqdn]}"
host="${3:-${app}.mankatotech.com}"

tmpl=/etc/nginx/templates/app.vhost.template
out="/etc/nginx/conf.d/${host}.conf"

[ -r "$tmpl" ] || { echo "add-app: template missing: $tmpl (run install.sh)" >&2; exit 1; }
if [ -e "$out" ]; then
    echo "add-app: $out already exists — remove it first to change the backend" >&2
    exit 1
fi

sed -e "s|@@HOSTNAME@@|${host}|g" \
    -e "s|@@SLUG@@|${app}|g" \
    -e "s|@@BACKEND@@|${backend}|g" \
    "$tmpl" > "$out"

if ! nginx -t 2>/tmp/add-app.nginx-test; then
    rm -f "$out"
    echo "add-app: nginx config test failed; reverted:" >&2
    cat /tmp/add-app.nginx-test >&2
    exit 1
fi

systemctl reload nginx
echo "add-app: ${host} -> http://${backend}"
echo "add-app: access log /var/log/nginx/${app}.access.log (JSON)"
