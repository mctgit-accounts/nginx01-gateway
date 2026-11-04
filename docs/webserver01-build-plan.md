# `webserver01` — app-tier build plan

**Status:** planned (not yet provisioned).

Purpose: a general-purpose app tier where custom web apps are built, tested and
served. It is never internet-reachable; the edge (`nginx01-gateway`) proxies to
it by name.

## Box

| | |
|---|---|
| Hypervisor | KVM on MCT-AUTOMATION-HOST (libvirt `qemu:///system`) |
| Name | `webserver01` |
| OS | Ubuntu 26.04 LTS cloud image |
| Specs | 4 vCPU / 8 GiB / 150 GB qcow2 |
| Autostart | on |

## Network

- One NIC: macvtap on host `eno2`, **`10.100.200.70/24`**, gw `10.100.200.1`
  (app tier / internal network — see ADR 0003).
- No LAN interface (management via the hypervisor host; ADR 0004).
- DNS `1.1.1.1` / `8.8.8.8`.

## Management

- SSH from the KVM host (`10.100.200.100`, same subnet).
- Fallback: `virsh -c qemu:///system console webserver01`.
- Key-only, no password auth.

## Build recipe

```bash
qemu-img convert ~/vm-staging/resolute-server-cloudimg-amd64.img \
  /var/lib/libvirt/images/webserver01.qcow2
sudo qemu-img resize /var/lib/libvirt/images/webserver01.qcow2 150G
cloud-localds -N seed/network-config seed/seed.iso seed/user-data seed/meta-data
sudo cp seed/seed.iso /var/lib/libvirt/images/webserver01-seed.iso
sudo chown libvirt-qemu:kvm /var/lib/libvirt/images/webserver01{,-seed.iso}*
sudo VIRTINSTALL_OSINFO_DISABLE_REQUIRE=1 virt-install --name webserver01 \
  --memory 8192 --vcpus 4 --machine q35 --boot uefi --autostart --import \
  --noautoconsole --graphics none --console pty,target_type=serial \
  --disk path=/var/lib/libvirt/images/webserver01.qcow2,format=qcow2,bus=virtio,discard=unmap \
  --disk path=/var/lib/libvirt/images/webserver01-seed.iso,device=cdrom,readonly=on \
  --network type=direct,source=eno2,source_mode=bridge,mac=52:54:00:0e:71:01,model=virtio
```

## Hardening (on the box)

- `ufw`: default deny incoming; allow app ports **only from `10.20.30.51`**;
  allow SSH **only from `10.100.200.100`**; default deny outgoing with only what
  builds need (package mirrors, registries).
- `unattended-upgrades` (security) + a patch cadence.
- No service listens on `0.0.0.0` beyond the intended app ports.
- Per-app isolation: Docker with per-container networking, or per-app users +
  cgroup limits. No app touches another's data.
- App + auth logs shipped to Wazuh (same agent/local-file pattern as the edge).
- Backups of app data/config; secrets never in git.

## WatchGuard rules to add (user applies)

| # | Action | From | To | Ports |
|---|---|---|---|---|
| 1 | Allow | edge `10.20.30.51` | app `10.100.200.70` | app ports only |
| 2 | Allow | app `10.100.200.70` | internet | 443 (+80) for builds — or via a proxy |
| 3 | Allow | office LAN / mgmt | app `10.100.200.70` | 22 (admin) |
| 4 | Deny | anything else | app `10.100.200.70` | any |

Never DNAT 80/443 to the app host — only to the edge.

## Runtime

- Node 24 LTS (NodeSource) and/or Docker, per app.
- Apps listen on `10.100.200.70:<port>`; the edge proxies to them.

## Database (later)

- PostgreSQL on a data-tier host (ADR 0005), reachable only from the app tier on
  `5432`. One cluster, a database + role per app.

## Acceptance

- [ ] VM up, `10.100.200.70` reachable from the edge on an app port.
- [ ] ufw: app port refused from any source except `10.20.30.51`.
- [ ] Not reachable from the internet (external probe).
- [ ] `add-app <app> 10.100.200.70:<port>` serves over HTTPS end-to-end.
- [ ] Host↔guest management works (or console documented as the path).
