// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell

// Catálogo de lo que se puede fijar en el menú de la isla y reglas de fijado.
// El estado (qué está fijado, en qué orden, y los accesos propios) vive en DisplayState.
Singleton {
    id: root
    readonly property int columns: 4
    readonly property int maxRows: 3
    readonly property int maxButtons: columns * maxRows

    readonly property var builtins: [
        { id: "volume", label: "Volumen", icon: "volume", slider: true },
        { id: "brightness", label: "Brillo", icon: "sun", slider: true },
        { id: "vibrance", label: "Saturación", icon: "drop", slider: true },
        { id: "terminal", label: "Terminal", icon: "terminal", slider: false },
        { id: "record", label: "Grabar pantalla", icon: "record", slider: false },
        { id: "capture", label: "Captura", icon: "capture", slider: false },
        { id: "desktops", label: "Escritorios", icon: "desktops", slider: false },
        { id: "clipboard", label: "Portapapeles", icon: "clipboard", slider: false }
    ]

    function isSlider(id) { return id === "volume" || id === "brightness" || id === "vibrance" }
    function custom(id) { return DisplayState.customItems.find(c => c.id === id) ?? null }
    function exists(id) { return builtins.some(b => b.id === id) || custom(id) !== null }

    // Fijados que existen (ignora accesos propios borrados).
    readonly property var pinnedSliders: DisplayState.pins.filter(p => isSlider(p))
    readonly property var pinnedButtons: DisplayState.pins.filter(p => !isSlider(p) && exists(p)).slice(0, maxButtons)
    readonly property bool full: pinnedButtons.length >= maxButtons

    function pinned(id) { return DisplayState.pins.indexOf(id) >= 0 }
    function canPin(id) { return pinned(id) || isSlider(id) || !full }
    function setPinned(id, on) {
        const rest = DisplayState.pins.filter(p => p !== id)
        if (on && !canPin(id)) return
        DisplayState.setPins(on ? rest.concat([id]) : rest)
    }
    function addCustom(label, cmd) {
        label = label.trim(); cmd = cmd.trim()
        if (!label || !cmd) return false
        const id = "c" + Date.now().toString(36)
        DisplayState.setCustomItems(DisplayState.customItems.concat([{ id: id, label: label, cmd: cmd }]))
        if (!full) setPinned(id, true)
        return true
    }
    function removeCustom(id) {
        DisplayState.setCustomItems(DisplayState.customItems.filter(c => c.id !== id))
        DisplayState.setPins(DisplayState.pins.filter(p => p !== id))
    }
    function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }
}
