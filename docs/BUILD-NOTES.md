# nginx01-gateway — build notes
(created 2026-11-04)

Purpose: single public front door for app hosting. Terminates TLS and
reverse-proxies `appN.mankatotech.com` to backends by name. Parallel to the
existing Caddy front door on `mct-opencode` (10.20.30.50); does not replace it.

## Box — CREATED 2026-11-04
- Hypervisor: KVM on MCT-AUTOMATION-HOST (libvirt, qemu:///system)
- VM name: `nginx01-gateway`   autostart: **ON**
- Specs: 4 vCPU, 8 GiB RAM, 60 GiB disk (qcow2 sparse, `discard=unmap`, virtio)
- OS: Ubuntu 26.04 LTS cloud image (`~/vm-staging/resolute-server-cloudimg-amd64.img`)
- UEFI/q35; two NICs (dual-homed, mirrors `mct-opencode`)

## Network — TWO NICS
- `web0`  (macvtap on host `enp6s0f1`, MAC `52:54:00:0e:51:01`): `10.20.30.51/24`,
  gw `10.20.30.1` (metric 200). **PUBLIC / app side.** WatchGuard DNAT
  `64.61.212.98:80,443 -> 10.20.30.51`.
- `chat0` (macvtap on host `eno3`, MAC `52:54:00:0e:51:02`): `192.168.0.51/24`,
  gw `192.168.0.1` (metric 100). **PRIVATE side**, office LAN. Admin/SSH here only.
- Default route prefers chat0. DNS 1.1.1.1/8.8.8.8.
- **First-boot caveat (known estate flakiness):** cloud-init failed to rename the
  first NIC (`[busy] Error renaming mac=...5101 from enp1s0 to web0`), so web0 came
  up as `enp1s0` with a DHCP address (`10.20.30.45`). Fix applied:
  `sudo ip link set enp1s0 down && sudo netplan apply` -> renamed to `web0` with
  the static address. netplan's `.link` files in `/run/systemd/network/`
  (`10-netplan-web0.link`) make the rename survive reboot — **verified across a
  reboot 2026-11-04**.

## Access
- SSH: `ssh -i ~/vms/nginx01-gateway/id_nginx01_gateway brian@192.168.0.51`
  (chat/LAN side only; key-only, no password auth)
- Console: `virsh -c qemu:///system console nginx01-gateway`
- Images: `/var/lib/libvirt/images/nginx01-gateway.qcow2` +
  `nginx01-gateway-seed.iso` (seed sources: `~/vms/nginx01-gateway/seed/`)

## Installed
- nginx 1.28.3 (Ubuntu), enabled + active. Serves default page on :80.
- Packages via cloud-init: qemu-guest-agent, curl, git, ca-certificates, ufw, nginx.

## Rebuild recipe
```
qemu-img convert ~/vm-staging/resolute-server-cloudimg-amd64.img \
  /var/lib/libvirt/images/nginx01-gateway.qcow2
sudo qemu-img resize /var/lib/libvirt/images/nginx01-gateway.qcow2 60G
cloud-localds -N seed/network-config seed/seed.iso seed/user-data seed/meta-data
sudo cp seed/seed.iso /var/lib/libvirt/images/nginx01-gateway-seed.iso
sudo chown libvirt-qemu:kvm /var/lib/libvirt/images/nginx01-gateway{,-seed.iso}.qcow2
sudo VIRTINSTALL_OSINFO_DISABLE_REQUIRE=1 virt-install --name nginx01-gateway \
  --memory 8192 --vcpus 4 --machine q35 --boot uefi --autostart --import \
  --noautoconsole --graphics none --console pty,target_type=serial \
  --disk path=/var/lib/libvirt/images/nginx01-gateway.qcow2,format=qcow2,bus=virtio,discard=unmap \
  --disk path=/var/lib/libvirt/images/nginx01-gateway-seed.iso,device=cdrom,readonly=on \
  --network type=direct,source=enp6s0f1,source_mode=bridge,mac=52:54:00:0e:51:01,model=virtio \
  --network type=direct,source=eno3,source_mode=bridge,mac=52:54:00:0e:51:02,model=virtio
# after first boot, if web0 did not take its static address:
#   ssh brian@192.168.0.51 'sudo ip link set enp1s0 down && sudo netplan apply'
```

## Keys / secrets
- Build SSH key: `~/vms/nginx01-gateway/id_nginx01_gateway` (pub embedded in seed)
- Repo deploy key: `~/.ssh/id_mct_nginx_gateway_repo` (for the gateway repo)

## Open / next
- WatchGuard (user): reserve `10.20.30.51` + `192.168.0.51` in DHCP; confirm
  `64.61.212.98` is bound for inbound DNAT (docs flagged `.98` as egress-only,
  unverified inbound).
- DNS: `app1..app5.mankatotech.com -> 64.61.212.98` added but **not published**
  by DreamHost nameservers yet (SOA serial unchanged at 2026-11-02).
- Next build: nginx config set (snippets + per-app vhosts), wildcard cert
  (`*.mankatotech.com` via DreamHost DNS-01), `add-app.sh` template, ufw rules,
  Wazuh log shipping.
