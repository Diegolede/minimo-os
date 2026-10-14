// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Vista de ventanas (Super+Tab). Con la vista abierta, Super+Tab otra vez pasa a la
// siguiente ventana (como Alt+Tab); soltar Super o Intro la enfoca.
//   qs -p ~/Proyectos/minimo-os/minimo-shell ipc call overview toggle
Singleton {
    id: root
    property bool open: false
    signal next()
    function toggle() { if (open) next(); else open = true }
    function hide() { open = false }

    IpcHandler {
        target: "overview"
        function toggle(): void { root.toggle() }
        function open(): void { root.open = true }
        function close(): void { root.hide() }
    }
}
