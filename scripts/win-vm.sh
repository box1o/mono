#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"

load_config win-vm
need_cmd qemu-system-x86_64

DISK="${WIN_VM_DISK:-}"

prepare_disk() {
	[[ -n "$DISK" ]] || die "WIN_VM_DISK missing in $(mono_config_file win-vm)"
	[[ "${WIN_VM_CHOWN:-true}" == true ]] || return 0
	sudo chown "${WIN_VM_OWNER:-$USER:kvm}" "$DISK"
}

run_vm() {
	qemu-system-x86_64 \
		-enable-kvm \
		-m "${WIN_VM_MEMORY:-12G}" \
		-cpu host,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time,topoext \
		-smp "${WIN_VM_SMP:-12,sockets=1,cores=12,threads=1}" \
		-drive "file=$DISK,format=raw,if=virtio,cache=none,aio=native" \
		-vga virtio \
		-display "${WIN_VM_DISPLAY:-sdl,gl=on}" \
		-device virtio-serial \
		-device virtio-balloon \
		-net nic,model=virtio \
		-net user \
		-usb \
		-device usb-tablet
}

prepare_disk
run_vm
