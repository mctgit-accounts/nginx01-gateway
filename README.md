# nginx01-gateway

Single public front door for `appN.mankatotech.com` app hosting. nginx terminates
TLS (wildcard `*.mankatotech.com` via Let's Encrypt DNS-01 / DreamHost) and
reverse-proxies each hostname to a backend by name.

Host: `nginx01-gateway` (KVM on MCT-AUTOMATION-HOST)
- `web0` 10.20.30.51/24  — public/app side (WatchGuard DNAT 64.61.212.98:80,443)
- `chat0` 192.168.0.51/24 — LAN admin side (SSH)

## Layout

```
deploy/
  nginx/
    log-format.conf                 # JSON access log format (http context)
    conf.d/10-map.conf              # $connection_upgrade map (WebSocket)
    conf.d/10-limits.conf           # limit_req / limit_conn zones
    conf.d/10-default.conf          # catch-all: HTTP->HTTPS, unknown host -> 444
    snippets/proxy-common.conf      # proxy headers + timeouts
    snippets/tls-common.conf        # TLS params + security headers
    templates/app.vhost.template    # per-app vhost template (@@PLACEHOLDERS@@)
  scripts/
    install.sh                      # deploy nginx configs to the host (root)
    add-app.sh                      # add-app <app> <host:port> [fqdn]
    harden.sh                       # ufw (external-scoped) + fail2ban (root)
  fail2ban/
    jail.local                      # jails: sshd, nginx-limit-req, json 401/403/444, recidive
    filter.d/nginx-gateway-json.conf
  wazuh/
    localfiles.conf                 # agent localfile blocks (nginx + fail2ban)
    manager-decoder-and-rules.xml   # custom fail2ban decoder + rules for the manager
  acme/                             # Let's Encrypt DNS-01 (DreamHost) hooks
```

## Security posture

- **ufw:** deny inbound; SSH only on `chat0` (LAN), 80/443 only on `web0` (public).
- **fail2ban:** external-scoped (internal nets in `ignoreip`); bans via `ufw`.
- **nginx:** per-IP `limit_req`/`limit_conn`; unknown hostnames get 444 and are
  logged to `blocked.access.log` for fail2ban/Wazuh.
- **Wazuh:** agent ships nginx access (JSON) + error + fail2ban logs to the manager.

## Add an app

```bash
sudo add-app app6 10.100.200.20:8080
# -> serves app6.mankatotech.com, proxies to http://10.100.200.20:8080
# -> access log /var/log/nginx/app6.access.log (JSON)
```

DNS (`app6.mankatotech.com -> 64.61.212.98`) and the wildcard cert already cover
new hosts; only the backend needs to exist.

## Install / update

```bash
sudo deploy/scripts/install.sh
```
