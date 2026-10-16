// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell
import "../../Common"
import "../../Common/confirm.js" as Confirm
import ".."

// Energía y Ajustes. Cerrar sesión / Reiniciar / Apagar piden confirmación con UNA sola
// máquina de estados (Common/confirm.js): solo una puede estar armada; el segundo clic
// ejecuta una vez y los clics siguientes se ignoran durante 2 s.
Row {
    id: root
    signal done()
    signal settings()

    readonly property var commands: ({
        logout: "hyprctl dispatch 'hl.dsp.exit()'",
        reboot: "systemctl reboot",
        poweroff: "systemctl poweroff"
    })
    property var st: Confirm.initial()
    readonly property string armed: st.armed

    function press(id) {
        const r = Confirm.press(st, id, Date.now(), 3000, 2000)
        st = r.state
        if (r.state.armed !== "") disarm.restart()
        if (r.run !== "") { Quickshell.execDetached(["sh", "-c", commands[r.run]]); root.done() }
    }
    function reset() { disarm.stop(); st = Confirm.disarm(st) }
    Timer { id: disarm; interval: 3000; onTriggered: root.st = Confirm.disarm(root.st) }

    MenuButton { icon: "logout"; label: "Cerrar sesión"; armed: root.armed === "logout"; onActivated: root.press("logout") }
    MenuButton { icon: "restart"; label: "Reiniciar"; armed: root.armed === "reboot"; onActivated: root.press("reboot") }
    MenuButton { icon: "power"; label: "Apagar"; armed: root.armed === "poweroff"; onActivated: root.press("poweroff") }
    MenuButton { icon: "settings"; label: "Ajustes"; onActivated: { root.reset(); root.settings() } }
}
