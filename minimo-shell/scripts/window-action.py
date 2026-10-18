#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
"""Acciones sobre UNA ventana desde la vista de escritorios de la isla.

  window-action.py move <dirección> <escritorio>   mueve sin seguirla (movetoworkspacesilent)
  window-action.py close <dirección>               pide cerrarla (closewindow: cierre amable)

Antes de actuar se vuelve a pedir la lista de ventanas a Hyprland (`hyprctl clients -j`):
si la ventana ya no existe no se hace nada. Nunca se mata un proceso (no hay "kill").
Sintaxis de dispatch Lua de Hyprland 0.56 (hl.dsp.window.move / hl.dsp.window.close).
Imprime un JSON: {"ok": bool, "reason": "...", "noop": bool}.
"""
import json, re, subprocess, sys


def hypr(*a):
    return subprocess.run(["hyprctl", *a], capture_output=True, text=True, timeout=5)


def out(ok, reason="", noop=False):
    print(json.dumps({"ok": ok, "reason": reason, "noop": noop}))
    return 0


def main(argv):
    if len(argv) < 2 or argv[0] not in ("move", "close") or (argv[0] == "move" and len(argv) < 3):
        return out(False, "usage")
    action, addr = argv[0], argv[1].lower()
    if not addr.startswith("0x"):
        addr = "0x" + addr
    # Validación estricta: lo que va dentro del texto Lua no puede inyectar nada.
    if not re.fullmatch(r"0x[0-9a-f]{1,16}", addr):
        return out(False, "bad-address")
    ws = argv[2] if action == "move" else ""
    if action == "move" and not re.fullmatch(r"[1-9][0-9]{0,3}|emptynm", ws):
        return out(False, "bad-workspace")
    try:
        clients = json.loads(hypr("clients", "-j").stdout or "[]")
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return out(False, "hyprctl")
    win = next((c for c in clients if str(c.get("address", "")).lower() == addr), None)
    if win is None:
        return out(False, "gone")
    if action == "move":
        cur = (win.get("workspace") or {}).get("id")
        if ws.isdigit() and cur == int(ws):
            return out(True, "same-workspace", noop=True)
        cmd = 'hl.dsp.window.move({ workspace = "%s", follow = false, window = "address:%s" })' % (ws, addr)
    else:
        cmd = 'hl.dsp.window.close({ window = "address:%s" })' % addr
    try:
        r = hypr("dispatch", cmd)
    except (OSError, subprocess.TimeoutExpired):
        return out(False, "hyprctl")
    res = (r.stdout or "").strip().lower()
    return out(r.returncode == 0 and (res == "" or res == "ok"), "" if res in ("", "ok") else res[:120])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
