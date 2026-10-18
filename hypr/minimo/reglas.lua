-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
-- Reglas de ventanas y capas.

local function flotar(clase) hl.window_rule({ match = { class = clase }, float = true }) end
local function mosaico(clase) hl.window_rule({ match = { class = clase }, tile = true }) end

-- Utilidades pequeñas que se ven mejor flotando.
for _, c in ipairs({
	"^(org\\.gnome\\.Calculator)$", "^(gnome-calculator)$", "^(galculator)$",
	"^(blueman-manager)$", "^(org\\.gnome\\.Nautilus)$", "^(xdg-desktop-portal)$", "^(zoom)$",
}) do flotar(c) end

-- Paneles de configuración y terminales que conviene acomodar en mosaico.
for _, c in ipairs({
	"^(org\\.wezfurlong\\.wezterm)$", "^(gnome-control-center)$", "^(pavucontrol)$", "^(nm-connection-editor)$",
}) do mosaico(c) end

hl.window_rule({ match = { class = "^(org\\.gnome\\.)" }, rounding = 12 })
-- Diálogo de contraseña (hyprpolkitagent): flotante y con el radio de las tarjetas de Minimo
-- (sus colores salen de hypr/hyprtoolkit/*.conf).
hl.window_rule({ match = { class = "^(hyprpolkitagent)$" }, float = true, rounding = 20 })
hl.window_rule({ match = { class = "^(firefox)$", title = "^(Picture-in-Picture)$" }, float = true })
hl.window_rule({ match = { class = "^(steam)$", title = "^(notificationtoasts)" }, no_initial_focus = true, pin = true })

-- Capas de la shell de Minimo: sin animación de Hyprland (la shell anima sola).
hl.layer_rule({ match = { namespace = "^(quickshell)$" }, no_anim = true })
hl.layer_rule({ match = { namespace = "^minimo-.*" }, no_anim = true })

