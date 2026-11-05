# webserver01 — build notes
(created 2026-11-04)

App tier for the web gateway: where custom web apps are built, tested and
served. Never internet-reachable; the edge (`nginx01-gateway`) proxies to it by
name. See `docs/webserver01-build-plan.md` and ADRs 0002/0003/0004.

## Box — CREATED 2026-11-04
- Hypervisor: KVM on MCT-AUTOMATION-HOST (libvirt `qemu:///system`)
- VM name: `webserver01`   autostart: **ON**
- Specs: 4 vCPU, 8 GiB RAM, 150 GiB disk (qcow2 sparse, `discard=unmap`, virtio)
- OS: Ubuntu 26.04 LTS cloud image
- UEFI/q35; one NIC (single-homed on the app tier)

## Network
- `enp1s0` (macvtap on host `eno2.103`, MAC `52:54:00:0e:71:01`): **`10.100.200.130/26`**,
  gw `10.100.200.129` (VLAN 103, `WEB-App-02`). App tier / internal network.
  Re-IPed from `10.100.200.70/24` during the 2026-11-05 VLAN migration.
- No LAN interface — management via the hypervisor host (ADR 0004).

## Access
- SSH: `ssh -i ~/vms/webserver01/id_webserver01 brian@10.100.200.130`
  (from the automation host, same subnet)
- Console: `virsh -c qemu:///system console webserver01`
- Images: `/var/lib/libvirt/images/webserver01.qcow2` + `-seed.iso`
  (seed sources: `~/vms/webserver01/seed/`)

## Hardening (applied)
- ufw: default deny incoming **and outgoing**.
  - in: `22/tcp` from `10.100.200.100` (management) only.
  - in: `8080:8099/tcp` from `10.20.30.51` (edge) only.
  - out: `53/udp`, `80,443/tcp`, `123/udp`, `22/tcp` (builds/updates).
- Verified: `canary -> 10.100.200.70:8080` **blocked**; localhost OK.

## App isolation (Unix accounts) — applied 2026-11-04
- Framework installed by `deploy/scripts/install-app-isolation.sh`:
  `webapp@.service` (systemd template) + `/usr/local/bin/add-appuser`.
- Each app: its own system user/group and `/srv/apps/<app>` (0700); runs via
  `systemctl enable --now webapp@<app>.service` as `User=<app>`.
- Unit hardening: `ProtectSystem=strict`, `ProtectHome`, `PrivateTmp`,
  `PrivateDevices`, `NoNewPrivileges`, restricted address families/namespaces.
- Limits: `CPUQuota=100%`, `MemoryMax=512M`, `TasksMax=256`.
- Verified: two apps run as separate users; one cannot read the other's files
  (Permission denied). See ADR 0008.

## Build caveat (important for future VMs)
The first cloud-init NIC **rename** (`set-name`) fails with `[busy]` when it is
the only NIC, leaving the guest with no address. Fix: **do not use `set-name`** on
a single-NIC cloud VM — key the netplan stanza on the predictable kernel name
(`enp1s0`) with `match: macaddress`. This VM was rebuilt that way and works.

## Rebuild recipe
```
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

## Open / next
- ~~WatchGuard: allow edge `10.20.30.51` → app ports (8080–8099)~~ — **done
  2026-11-05**; `app1` is proxied via the app tier.
- WatchGuard: confirm app → internet egress for builds.
- Install app runtime (Node LTS and/or Docker).
- Ship app logs to Wazuh.
- PostgreSQL data tier (ADR 0005).
