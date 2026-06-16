#!/usr/bin/env python3
"""ZMQ SUB on phone — system :55082 (local), sent :55092."""

import json
import sys
import time

import zmq

HOST = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
PORTS = (
    (55082, "system", "\033[36m"),  # cyan — USB/system on phone
    (55092, "sent", "\033[32m"),    # green — gateway / mgr_sim events
)
RESET = "\033[0m"
USE_COLOR = sys.stdout.isatty()


def connect_sock(ctx, host, port):
    sock = ctx.socket(zmq.SUB)
    sock.setsockopt_string(zmq.SUBSCRIBE, "")
    for _ in range(30):
        try:
            sock.connect(f"tcp://{host}:{port}")
            return sock
        except zmq.ZMQError:
            time.sleep(0.5)
    sock.close(0)
    return None


ctx = zmq.Context()
sockets = {}

for port, label, color in PORTS:
    sock = connect_sock(ctx, HOST, port)
    if sock is None:
        print(f"WARN: no tcp://{HOST}:{port} ({label})", flush=True)
        continue
    sockets[sock] = (port, label, color)
    print(f"listen tcp://{HOST}:{port} ({label})", flush=True)

if not sockets:
    print("failed to connect any port", flush=True)
    sys.exit(1)

print("ready — trigger mgr_sim, mgr, or gateway now", flush=True)

poller = zmq.Poller()
for sock in sockets:
    poller.register(sock, zmq.POLLIN)

try:
    while True:
        for sock, _ in poller.poll():
            port, label, color = sockets[sock]
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
                if USE_COLOR:
                    print(f"{color}{prefix}{RESET}{body}", flush=True)
                else:
                    print(f"{prefix}{body}", flush=True)
except KeyboardInterrupt:
    print("stopped", flush=True)
finally:
    for sock in sockets:
        sock.close(0)
    ctx.term()
