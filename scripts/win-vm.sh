#!/bin/bash

sudo chown toor:kvm /dev/nvme1n1

qemu-system-x86_64 \
  -enable-kvm \
  -m 12G \
  -cpu host,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time,topoext \
  -smp 12,sockets=1,cores=12,threads=1 \
  -drive file=/dev/nvme1n1,format=raw,if=virtio,cache=none,aio=native \
  -vga virtio \
  -display sdl,gl=on \
  -device virtio-serial \
  -device virtio-balloon \
  -net nic,model=virtio \
  -net user \
  -usb -device usb-tablet
