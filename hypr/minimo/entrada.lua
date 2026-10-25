-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
-- Entrada: distribución del sistema, Bloq Num activo, foco solo con clic, touchpad natural.

hl.config({
	input = {
		kb_layout = "",               -- vacío: usa XKB_DEFAULT_LAYOUT (o "us")
		numlock_by_default = true,
		follow_mouse = 0,             -- el foco no sigue al mouse
		touchpad = {
			tap_to_click = true,
			natural_scroll = true,
			disable_while_typing = true,   -- la palma no mueve el puntero mientras escribís
			clickfinger_behavior = true,   -- clic con dos dedos = clic derecho (como en macOS)
			drag_lock = true,              -- arrastrar con toque: levantar el dedo un instante no suelta
		},
	},
	gestures = {
		workspace_swipe_distance = 260,          -- recorrido más corto: menos esfuerzo
		workspace_swipe_cancel_ratio = 0.25,     -- un desliz corto que no llega se cancela suave
		workspace_swipe_min_speed_to_force = 20, -- un golpe rápido cambia aunque sea corto
		workspace_swipe_forever = true,          -- sin soltar, sigue pasando escritorios
	},
})

-- Tres dedos en horizontal: cambiar de escritorio.
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
