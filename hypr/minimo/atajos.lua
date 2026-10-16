-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
-- Atajos de teclado de Minimo OS. Super es la tecla principal.

local bind, dsp = hl.bind, hl.dsp
local qs = "qs -p " .. os.getenv("HOME") .. "/Proyectos/minimo-os/minimo-shell ipc call "

-- Aplicaciones y shell
bind("SUPER + T", dsp.exec_cmd("ghostty"))
bind("SUPER + space", dsp.exec_cmd("fuzzel"))
bind("SUPER + comma", dsp.exec_cmd(qs .. "settings toggle"))
bind("SUPER + X", dsp.exec_cmd(qs .. "island open"))
bind("SUPER + SHIFT + R", dsp.exec_cmd(qs .. "recorder toggle"))

-- Sesión
bind("SUPER + SHIFT + E", dsp.exit())
bind("SUPER + SHIFT + P", dsp.dpms({ action = "toggle" }))

-- Volumen y música (funcionan también con la pantalla bloqueada)
local fijo, repite = { locked = true }, { locked = true, repeating = true }
bind("XF86AudioRaiseVolume", dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 3%+"), repite)
bind("XF86AudioLowerVolume", dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 3%-"), repite)
bind("XF86AudioMute", dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), fijo)
bind("XF86AudioMicMute", dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), fijo)
bind("XF86AudioPlay", dsp.exec_cmd("playerctl play-pause"), fijo)
bind("XF86AudioPause", dsp.exec_cmd("playerctl play-pause"), fijo)
bind("XF86AudioNext", dsp.exec_cmd("playerctl next"), fijo)
bind("XF86AudioPrev", dsp.exec_cmd("playerctl previous"), fijo)

-- Capturas (en ~/Imágenes/Capturas y al portapapeles; aviso con miniatura)
local shot = os.getenv("HOME") .. "/Proyectos/minimo-os/minimo-shell/scripts/screenshot.sh "
bind("Print", dsp.exec_cmd(shot .. "area"))
bind("CTRL + Print", dsp.exec_cmd(shot .. "full"))

-- Ventanas
bind("SUPER + Q", dsp.window.close())
bind("SUPER + F", dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
bind("SUPER + SHIFT + F", dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
bind("SUPER + CTRL + F", dsp.window.fullscreen({ mode = "maximized", action = "set" }))
bind("SUPER + SHIFT + T", dsp.window.float({ action = "toggle" }))
bind("SUPER + W", dsp.group.toggle())
bind("SUPER + R", dsp.layout("togglesplit"))
bind("SUPER + bracketleft", dsp.layout("preselect l"))
bind("SUPER + bracketright", dsp.layout("preselect r"))
bind("SUPER + Home", dsp.focus({ window = "first" }))
bind("SUPER + End", dsp.focus({ window = "last" }))

-- Mover/redimensionar con el mouse (Super + clic izquierdo/derecho)
bind("SUPER + mouse:272", dsp.window.drag(), { mouse = true, description = "Mover ventana" })
bind("SUPER + mouse:273", dsp.window.resize(), { mouse = true, description = "Redimensionar ventana" })

-- Redimensionar con teclado
local r = { repeating = true }
bind("SUPER + minus", dsp.window.resize({ x = -100, y = 0, relative = true }), r)
bind("SUPER + equal", dsp.window.resize({ x = 100, y = 0, relative = true }), r)
bind("SUPER + SHIFT + minus", dsp.window.resize({ x = 0, y = -100, relative = true }), r)
bind("SUPER + SHIFT + equal", dsp.window.resize({ x = 0, y = 100, relative = true }), r)
bind("SUPER + code:20", dsp.window.resize({ x = -100, y = 0, relative = true }))
bind("SUPER + code:21", dsp.window.resize({ x = 100, y = 0, relative = true }))

-- Foco, mover ventana y monitores: flechas o h/j/k/l
local dirs = { left = "l", down = "d", up = "u", right = "r", H = "l", J = "d", K = "u", L = "r" }
for tecla, d in pairs(dirs) do
	bind("SUPER + " .. tecla, dsp.focus({ direction = d }))
	bind("SUPER + SHIFT + " .. tecla, dsp.window.move({ direction = d }))
	bind("SUPER + SHIFT + CTRL + " .. tecla, dsp.window.move({ monitor = d }))
end
for tecla, d in pairs({ left = "l", right = "r", H = "l", J = "d", K = "u", L = "r" }) do
	bind("SUPER + CTRL + " .. tecla, dsp.focus({ monitor = d }))
end

-- Escritorios: anterior/siguiente (no vacíos)
for _, t in ipairs({ { "Page_Down", "U", "e+1" }, { "Page_Up", "I", "e-1" } }) do
	local a, b, ws = t[1], t[2], t[3]
	bind("SUPER + " .. a, dsp.focus({ workspace = ws }))
	bind("SUPER + " .. b, dsp.focus({ workspace = ws }))
	bind("SUPER + SHIFT + " .. a, dsp.window.move({ workspace = ws }))
	bind("SUPER + SHIFT + " .. b, dsp.window.move({ workspace = ws }))
	bind("SUPER + CTRL + " .. b, dsp.window.move({ workspace = ws }))
end
bind("SUPER + CTRL + down", dsp.window.move({ workspace = "e+1" }))
bind("SUPER + CTRL + up", dsp.window.move({ workspace = "e-1" }))
bind("SUPER + mouse_down", dsp.focus({ workspace = "e+1" }))
bind("SUPER + mouse_up", dsp.focus({ workspace = "e-1" }))
bind("SUPER + CTRL + mouse_down", dsp.window.move({ workspace = "e+1" }))
bind("SUPER + CTRL + mouse_up", dsp.window.move({ workspace = "e-1" }))

-- Escritorios 1–9
for i = 1, 9 do
	bind("SUPER + " .. i, dsp.focus({ workspace = tostring(i) }))
	bind("SUPER + SHIFT + " .. i, dsp.window.move({ workspace = tostring(i) }))
end
