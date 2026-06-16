# scripts

## MGW via `d` (~)

```bash
cd ~
d relay MGW-6
d relay MGW-2 ug-dev-v50-15218
d scrcpy MGW-6
```

## MGW + bridge

```bash
mgw mgw6
bridge.sh relay mgw6
# optional: bridge.sh relay mgw2 my-container

bridge.sh listen mgw6

mgw login mgw6
# separate shell into rootfs

apt update
apt install python3-zmq
python3 -c "import zmq; print(zmq.pyzmq_version())"

```

Container defaults to first running `ug-dev-v50*`.

Ports: `55082` system (phone, local) · `55092` sent (relay from container)

Relay only forwards `:55092` (container PUB). `:55082` is listened on the phone directly.

In container: `python3 sim/mgr_sim.py` → `run`
