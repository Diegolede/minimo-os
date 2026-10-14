// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Mini mascota: tres medidores que se calculan a partir de marcas de tiempo (sin
// tick de fondo). Solo mientras el panel está abierto se recalcula una vez por minuto.
//   · Comida: baja en 8 h desde la última vez que comió.
//   · Ánimo: baja en 5 h desde el último juego.
//   · Energía: baja en 2 h de uso continuo de la PC y se recarga con una pausa real
//     (inactividad de teclado y mouse, la misma que lo hace dormir).
Singleton {
    id: root
    readonly property real foodSpan: 8 * 3600000
    readonly property real funSpan: 5 * 3600000
    readonly property real energySpan: 2 * 3600000

    property real lastFed: Date.now()
    property real lastPlayed: Date.now()
    property real activeSince: Date.now()      // inicio del tramo actual sin pausas (no se guarda)
    property real now: Date.now()
    property int watchers: 0

    function clamp(v) { return Math.max(0, Math.min(1, v)) }
    readonly property real food: clamp(1 - (now - lastFed) / foodSpan)
    readonly property real fun: clamp(1 - (now - lastPlayed) / funSpan)
    readonly property real energy: IdleState.idle ? 1 : clamp(1 - (now - activeSince) / energySpan)
    readonly property int activeMinutes: Math.max(0, Math.round((now - activeSince) / 60000))

    // "tired" | "worried" | "" (para el ánimo del personaje)
    readonly property string mood: energy < 0.25 ? "tired" : (food < 0.25 || fun < 0.2) ? "worried" : ""

    function acquire() { watchers++; now = Date.now() }
    function release() { watchers = Math.max(0, watchers - 1) }
    function feed() { lastFed = Date.now(); now = lastFed; save() }
    function play() { lastPlayed = Date.now(); now = lastPlayed; save() }

    Timer { interval: 60000; repeat: true; running: root.watchers > 0; onTriggered: root.now = Date.now() }
    Connections {
        target: IdleState
        function onIdleChanged() { if (!IdleState.idle) { root.activeSince = Date.now(); root.now = root.activeSince } }
    }

    function save() { file.setText(JSON.stringify({ lastFed: root.lastFed, lastPlayed: root.lastPlayed })) }
    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/minimo-os/pet.json"
        blockLoading: false
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text())
                if (s.lastFed > 0) root.lastFed = Math.min(s.lastFed, Date.now())
                if (s.lastPlayed > 0) root.lastPlayed = Math.min(s.lastPlayed, Date.now())
            } catch (e) {}
        }
    }
}
