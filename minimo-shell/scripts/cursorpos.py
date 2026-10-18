#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
# Posición del cursor para el personaje, sin lanzar hyprctl: un solo proceso que consulta
# el socket IPC de Hyprland. ~20 Hz mientras el mouse se mueve, ~3 Hz si está quieto >1 s y
# ~1,5 Hz si lleva >10 s quieto (para entonces el personaje ya dejó de seguirlo: mira al frente).
# Imprime "x,y" solo cuando cambia. Termina si la shell cierra la salida.
import os, socket, sys, time

def sock_path():
    rt = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not sig:
        if not os.path.isdir(os.path.join(rt, "hypr")):
            sys.exit(1)                         # sin Hyprland: la shell reintenta
        ds = sorted(os.listdir(os.path.join(rt, "hypr")), key=lambda d: os.path.getmtime(os.path.join(rt, "hypr", d)))
        sig = ds[-1]
    return os.path.join(rt, "hypr", sig, ".socket.sock")

def query(path):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.settimeout(0.5)
        s.connect(path)
        s.sendall(b"cursorpos")
        data = b""
        while True:
            chunk = s.recv(256)
            if not chunk: break
            data += chunk
    return data.decode(errors="ignore").strip()

path, last, still_since, fails = sock_path(), None, time.monotonic(), 0
while True:
    try:
        pos = query(path); fails = 0
    except OSError:
        fails += 1
        if fails > 20: sys.exit(1)          # Hyprland no responde: la shell relanza el proceso
        time.sleep(0.5); path = sock_path(); continue
    now = time.monotonic()
    if pos != last:
        last, still_since = pos, now
        try:
            print(pos, flush=True)
        except BrokenPipeError:
            sys.exit(0)
    still = now - still_since
    time.sleep(0.05 if still < 1.0 else 0.33 if still < 10.0 else 0.66)
