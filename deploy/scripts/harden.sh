#!/usr/bin/env bash
# Harden nginx01-gateway: host firewall (ufw) + fail2ban (external-facing).
# Run as root.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"   # deploy/

# --- fail2ban ---
if ! command -v fail2ban-server >/dev/null; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y fail2ban
fi
install -d /etc/fail2ban/filter.d /etc/fail2ban/jail.d
install -m 0644 "$here/fail2ban/filter.d/nginx-gateway-json.conf" \
    /etc/fail2ban/filter.d/nginx-gateway-json.conf
install -m 0644 "$here/fail2ban/jail.local" \
    /etc/fail2ban/jail.d/nginx01-gateway.local

# --- ufw: deny inbound by default; SSH only on chat0; 80/443 only on web0 ---
ufw default deny incoming
ufw default allow outgoing
ufw allow in on chat0 to any port 22 proto tcp
ufw allow in on web0 to any port 80,443 proto tcp
ufw --force enable

systemctl enable --now fail2ban
systemctl restart fail2ban
sleep 1
echo "harden.sh: ufw + fail2ban applied"
fail2ban-client status 2>/dev/null | head -3 || true
