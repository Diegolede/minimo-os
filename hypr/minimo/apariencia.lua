-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
-- Apariencia: ventanas con esquinas de 12 px, huecos finos, sin bordes y sombra suave.

local acento = "rgb(9aa38f)"    -- verde grisáceo
local apagado = "rgb(807f7c)"
local bloqueado = "rgb(ff7568)"

hl.config({
	general = {
		layout = "dwindle",
		gaps_in = 4,
		gaps_out = 4,
		border_size = 0,
		resize_on_border = false,
		col = { active_border = acento, inactive_border = apagado },
	},
	decoration = {
		rounding = 12,
		active_opacity = 1.0,
		inactive_opacity = 1.0,
		shadow = {
			enabled = true,
			range = 30,
			render_power = 5,
			offset = "0 5",
			color = "rgba(00000070)",
		},
	},
	group = {
		col = {
			border_active = acento,
			border_inactive = apagado,
			border_locked_active = bloqueado,
			border_locked_inactive = apagado,
		},
		groupbar = {
			col = { active = acento, inactive = apagado, locked_active = bloqueado, locked_inactive = apagado },
		},
	},
	dwindle = { preserve_split = true },
	master = { mfact = 0.5 },
	misc = {
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		-- Pantalla apagada por DPMS (Super+Shift+M o la isla): vuelve con el mouse o una tecla.
		mouse_move_enables_dpms = true,
		key_press_enables_dpms = true,
	},
})

-- Animaciones cortas con la curva por defecto.
for leaf, speed in pairs({ windowsIn = 3, windowsOut = 3, windowsMove = 4, workspaces = 5, fade = 3, border = 3 }) do
	hl.animation({ leaf = leaf, enabled = true, speed = speed, bezier = "default" })
end
