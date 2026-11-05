#!/usr/bin/env bash
# Installs the app-isolation framework on the app tier (webserver01). Run as root.
#   - systemd template unit webapp@.service (per-app user + hardening + limits)
#   - /usr/local/bin/add-appuser helper
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"   # deploy/

install -d /srv/apps
install -m 0644 "$here/systemd/webapp@.service" /etc/systemd/system/webapp@.service
install -m 0755 "$here/scripts/add-appuser.sh" /usr/local/bin/add-appuser
systemctl daemon-reload
echo "install-app-isolation.sh: installed webapp@.service + add-appuser"
