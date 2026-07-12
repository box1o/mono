#!/usr/bin/env python3
import json
import sys
import time
import zmq

host = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
ports = ((55082, "system", "\033[36m"), (55092, "sent", "\033[32m"))
reset = "\033[0m"
color = sys.stdout.isatty()
ctx = zmq.Context()
sockets = {}
for port, label, ansi in ports:
    sock = ctx.socket(zmq.SUB)
    sock.setsockopt_string(zmq.SUBSCRIBE, "")
    sock.connect(f"tcp://{host}:{port}")
    sockets[sock] = (port, label, ansi)
    print(f"listen tcp://{host}:{port} ({label})", flush=True)
if not sockets:
    raise SystemExit("failed to connect any port")
print("ready", flush=True)
poller = zmq.Poller()
for sock in sockets:
    poller.register(sock, zmq.POLLIN)
try:
    while True:
        for sock, _ in poller.poll():
            port, label, ansi = sockets[sock]
            while True:
                try:
                    raw = sock.recv_string(zmq.NOBLOCK)
                except zmq.Again:
                    break
                try:
                    body = json.dumps(json.loads(raw), ensure_ascii=False)
                except json.JSONDecodeError:
                    body = raw
                prefix = f"[{port}/{label}] "
                print(f"{ansi}{prefix}{reset}{body}" if color else f"{prefix}{body}", flush=True)
except KeyboardInterrupt:
    print("stopped", flush=True)
finally:
    for sock in sockets:
        sock.close(0)
    ctx.term()
