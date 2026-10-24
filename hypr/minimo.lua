-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
-- Minimo OS: atajos propios (cargado al final de hyprland.lua).

-- Super+B: lanzador de aplicaciones de Minimo (IpcHandler "launcher" en la shell).
hl.bind("SUPER + B", hl.dsp.exec_cmd("qs -p " .. os.getenv("HOME") .. "/Proyectos/minimo-os/minimo-shell ipc call launcher toggle"))

-- Super+V: historial del portapapeles en la isla (fijados arriba).
hl.bind("SUPER + V", hl.dsp.exec_cmd("qs -p " .. os.getenv("HOME") .. "/Proyectos/minimo-os/minimo-shell ipc call island clipboard"))

-- Super+Tab: vista de ventanas (otra vez Tab: siguiente; soltar Super: ir a esa ventana).
hl.bind("SUPER + Tab", hl.dsp.exec_cmd("qs -p " .. os.getenv("HOME") .. "/Proyectos/minimo-os/minimo-shell ipc call overview toggle"))

-- Super+Shift+Escape: rescate si la interfaz se tilda (reinicia la shell de Minimo y recarga Hyprland, sin cerrar apps).
hl.bind("SUPER + SHIFT + Escape", hl.dsp.exec_cmd("sh -c 'systemctl --user restart minimo-shell; hyprctl reload'"))
