#!/usr/bin/env bash
# add-appuser <app> [port]
#
# Creates an isolated app account on the app tier:
#   - a system user/group named <app> (no login, no sudo),
#   - its own directory /srv/apps/<app> (mode 0700, owned by <app>),
#   - a systemd instance webapp@<app> running it under that user.
#
# Isolation: the app can only touch its own directory and a private /tmp; the
# system is read-only to it (ProtectSystem=strict) and it has cgroup CPU/memory
# limits. It cannot read any other app's files.
set -euo pipefail

app="${1:?usage: add-appuser <app> [port]}"
port="${2:-}"

if ! [[ "$app" =~ ^[a-z][a-z0-9-]{1,30}$ ]]; then
    echo "add-appuser: invalid app name '$app' (lowercase letters, digits, hyphens; start with a letter)" >&2
    exit 1
fi

if ! id "$app" >/dev/null 2>&1; then
    useradd --system --user-group --home-dir "/srv/apps/$app" \
        --no-create-home --shell /usr/sbin/nologin "$app"
fi
install -d -o "$app" -g "$app" -m 0700 "/srv/apps/$app"

if [ ! -e "/srv/apps/$app/run.sh" ]; then
    cat > "/srv/apps/$app/run.sh" <<'EOS'
#!/usr/bin/env bash
# Start the app here. It must listen on $PORT, bound to the host address.
echo "app not configured yet (edit $0)" >&2
sleep infinity
EOS
    chown "$app:$app" "/srv/apps/$app/run.sh"
    chmod 0750 "/srv/apps/$app/run.sh"
fi

if [ -n "$port" ]; then
    install -d "/etc/systemd/system/webapp@$app.service.d"
    cat > "/etc/systemd/system/webapp@$app.service.d/10-port.conf" <<EOF
[Service]
Environment=PORT=$port
EOF
fi

systemctl daemon-reload
systemctl enable "webapp@$app.service" >/dev/null 2>&1 || true

echo "add-appuser: created '$app' — user=$app, dir=/srv/apps/$app${port:+, PORT=$port}"
echo "add-appuser: put the app in /srv/apps/$app, then: systemctl start webapp@$app.service"
