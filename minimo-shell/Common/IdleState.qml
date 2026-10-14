// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland

// Inactividad de TODA la PC (protocolo ext-idle-notify): sin teclado ni mouse en
// ningún lado durante DisplayState.sleepMinutes, el personaje se duerme. Respeta los
// inhibidores (videos, etc.). `sleepNow()` fuerza el sueño hasta la próxima actividad.
Singleton {
    id: root
    property bool forced: false
    readonly property bool sleeping: monitor.isIdle || forced
    readonly property bool idle: monitor.isIdle          // inactividad real (pausa de la persona)
    // Nadie mira la pantalla (inactividad real, no sueño forzado): se pausan animaciones continuas.
    // Tras 10 min dormido pasa a "sueño profundo": recién ahí se congelan respiración y z.
    readonly property bool unattended: monitor.isIdle && deep.fired
    Timer { id: deep; property bool fired: false; interval: 600000; running: monitor.isIdle; onRunningChanged: if (!running) fired = false; onTriggered: fired = true }

    function sleepNow() { forced = true }
    function wake() { forced = false }

    IdleMonitor {
        id: monitor
        timeout: Math.max(1, DisplayState.sleepMinutes) * 60
        respectInhibitors: true
        onIsIdleChanged: if (!isIdle) root.forced = false
    }
}
