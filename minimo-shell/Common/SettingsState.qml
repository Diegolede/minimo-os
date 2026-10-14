// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Estado de la ventana de Ajustes. Desde Hyprland / terminal:
//   qs -p ~/Proyectos/minimo-os/minimo-shell ipc call settings toggle
//   qs -p ~/Proyectos/minimo-os/minimo-shell ipc call settings section pantalla
Singleton {
    id: root
    property bool open: false
    property string section: "personalizacion"   // "personalizacion" | "pantalla" | "atajos" | "minimo"
    function toggle() { open = !open }
    function show() { open = true }
    function hide() { open = false }

    IpcHandler {
        target: "settings"
        function toggle(): void { root.toggle() }
        function open(): void { root.show() }
        function close(): void { root.hide() }
        function section(name: string): void { root.section = name; root.show() }
    }
}
