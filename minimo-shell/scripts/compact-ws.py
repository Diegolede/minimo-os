#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
# Compacta escritorios: si quedó un hueco (p. ej. 1 y 3 con ventanas), las ventanas de 3
# pasan a 2, etc. Si estás parado en un escritorio vacío no hace nada (se compacta al
# salir). Se ejecuta por eventos de Hyprland (sin sondeo). Uso: compact-ws.py [--dry-run]
import json, subprocess, sys

def hypr(*a):
    return subprocess.run(["hyprctl", *a], capture_output=True, text=True, timeout=5).stdout

def main():
    dry = "--dry-run" in sys.argv
    active = (json.loads(hypr("activeworkspace", "-j") or "{}") or {}).get("id", -1)
    by_ws = {}
    for c in json.loads(hypr("clients", "-j") or "[]"):
        wid = (c.get("workspace") or {}).get("id", -1)
        if wid > 0 and c.get("mapped", True):
            by_ws.setdefault(wid, []).append(c["address"])
    if active > 0 and active not in by_ws:
        return                            # el usuario está en un escritorio vacío
    occ = sorted(by_ws)
    moves = [(src, i + 1) for i, src in enumerate(occ) if src != i + 1]
    if not moves: return
    if dry: print(json.dumps(moves)); return
    for src, dst in moves:
        for a in by_ws[src]:
            hypr("dispatch", 'hl.dsp.window.move({ workspace = "%d", follow = false, window = "address:%s" })' % (dst, a))
    if active in occ and active != occ.index(active) + 1:
        hypr("dispatch", 'hl.dsp.focus({ workspace = "%d" })' % (occ.index(active) + 1))

if __name__ == "__main__":
    main()
