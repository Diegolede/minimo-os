// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell
import "../../Common"
import ".."

// Energía (piden confirmación) y Ajustes. Los accesos rápidos están en PinnedSection.
Row {
    id: root
    signal done()
    signal settings()

    function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); root.done() }

    MenuButton { icon: "logout"; label: "Cerrar sesión"; confirm: true; onActivated: root.run("hyprctl dispatch 'hl.dsp.exit()'") }
    MenuButton { icon: "restart"; label: "Reiniciar"; confirm: true; onActivated: root.run("systemctl reboot") }
    MenuButton { icon: "power"; label: "Apagar"; confirm: true; onActivated: root.run("systemctl poweroff") }
    MenuButton { icon: "settings"; label: "Ajustes"; onActivated: root.settings() }
}
