#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
# Batería para la isla. "once": imprime un JSON (o null si no hay batería) y sale.
# "watch": imprime un JSON por cambio, por eventos de UPower (upower --monitor); sin
# upower, revisa cada 60 s. Solo se lanza si hay batería, así que en PCs de escritorio no
# cuesta nada. Simulador: si existe ~/.cache/minimo/fake-battery.json se usa ese archivo
# (scripts/fake-laptop.sh lo escribe y avisa a la shell); si no existe, no hace nada.
# Línea extra: {"backlight": bool} indica si hay brillo real (/sys/class/backlight + brightnessctl).
import json, os, shutil, subprocess, sys, time

FAKE = os.path.expanduser("~/.cache/minimo/fake-battery.json")
BASE = "/sys/class/power_supply"

def num(x):
    try: return int(float(x))
    except (TypeError, ValueError): return 0

def fake():
    try:
        with open(FAKE) as fh: j = json.load(fh)
        return {"pct": num(j.get("pct", 100)), "status": j.get("status", "Discharging"),
                "mins": j.get("mins"), "fake": True}
    except (OSError, ValueError): return None

def real():
    for d in (sorted(os.listdir(BASE)) if os.path.isdir(BASE) else []):
        p = f"{BASE}/{d}"
        def rd(n):
            try:
                with open(f"{p}/{n}") as fh: return fh.read().strip()
            except OSError: return ""
        if rd("type") != "Battery" or rd("scope") == "Device": continue
        pct = num(rd("capacity")); st = rd("status")
        mins = None
        now = num(rd("energy_now") or rd("charge_now")); rate = num(rd("power_now") or rd("current_now"))
        full = num(rd("energy_full") or rd("charge_full"))
        if rate > 0:
            if st == "Discharging": mins = round(60 * now / rate)
            elif st == "Charging" and full > now: mins = round(60 * (full - now) / rate)
        return {"pct": pct, "status": st, "mins": mins}
    return None

def read():
    return fake() if os.path.exists(FAKE) else real()

def out(x):
    print(json.dumps(x), flush=True)

def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "once"
    if mode == "once":
        bl = bool(os.path.isdir("/sys/class/backlight") and os.listdir("/sys/class/backlight") and shutil.which("brightnessctl"))
        out({"battery": read(), "backlight": bl}); return
    last = None
    def emit():
        nonlocal last
        b = read()
        if b != last: last = b; out(b)
    emit()
    if os.path.exists(FAKE):
        while True: time.sleep(3600)      # el simulador avisa con "laptop rescan"
    if shutil.which("upower"):
        p = subprocess.Popen(["upower", "--monitor"], stdout=subprocess.PIPE, text=True)
        for _ in p.stdout: emit()
    while True:
        time.sleep(60); emit()

if __name__ == "__main__":
    main()
