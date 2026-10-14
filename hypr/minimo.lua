-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
-- Minimo OS: atajos propios (cargado al final de hyprland.lua).

-- Super+B: lanzador de aplicaciones de Minimo (IpcHandler "launcher" en la shell).
hl.bind("SUPER + B", hl.dsp.exec_cmd("qs -p " .. os.getenv("HOME") .. "/Proyectos/minimo-os/minimo-shell ipc call launcher toggle"))

-- Super+V: historial del portapapeles en la isla (fijados arriba).
hl.bind("SUPER + V", hl.dsp.exec_cmd("qs -p " .. os.getenv("HOME") .. "/Proyectos/minimo-os/minimo-shell ipc call island clipboard"))
