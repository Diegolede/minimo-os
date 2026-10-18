// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import "pinorder.js" as PinOrder

// Catálogo de lo que se puede fijar en el menú de la isla y reglas de fijado.
// El estado (qué está fijado, en qué orden, y los accesos propios) vive en DisplayState.
Singleton {
    id: root
    readonly property int columns: 4
    readonly property int maxRows: 3
    readonly property int maxButtons: columns * maxRows

    readonly property var builtins: [
        { id: "volume", label: I18n.tr("Volumen"), icon: "volume", slider: true },
        { id: "brightness", label: I18n.tr("Brillo"), icon: "sun", slider: true },
        { id: "vibrance", label: I18n.tr("Saturación"), icon: "drop", slider: true },
        { id: "terminal", label: "Terminal", icon: "terminal", slider: false },
        { id: "record", label: I18n.tr("Grabar pantalla"), icon: "record", slider: false },
        { id: "capture", label: I18n.tr("Captura"), icon: "capture", slider: false },
        { id: "desktops", label: I18n.tr("Escritorios"), icon: "desktops", slider: false },
        { id: "clipboard", label: I18n.tr("Portapapeles"), icon: "clipboard", slider: false },
        { id: "notes", label: I18n.tr("Notas"), icon: "note", slider: false },
        { id: "emoji", label: I18n.tr("Emojis"), icon: "emoji", slider: false },
        { id: "browser", label: I18n.tr("Navegador"), icon: "globe", slider: false },
        { id: "files", label: I18n.tr("Archivos"), icon: "folder", slider: false }
    ]

    function isSlider(id) { return id === "volume" || id === "brightness" || id === "vibrance" }
    function custom(id) { return DisplayState.customItems.find(c => c.id === id) ?? null }
    function exists(id) { return builtins.some(b => b.id === id) || custom(id) !== null }

    // Fijados que existen (ignora accesos propios borrados).
    // Orden de todos los elementos (catálogo + propios); define el orden en la isla.
    readonly property var allIds: builtins.map(b => b.id).concat(DisplayState.customItems.map(c => c.id))
    readonly property var order: PinOrder.full(DisplayState.pinOrder, DisplayState.pins, allIds)
    readonly property var orderedPins: PinOrder.sortPins(DisplayState.pins, order)
    readonly property var pinnedSliders: orderedPins.filter(p => isSlider(p))
    readonly property var pinnedButtons: orderedPins.filter(p => !isSlider(p)).slice(0, maxButtons)
    function item(id) { return builtins.find(b => b.id === id) ?? custom(id) }
    function move(id, delta) { DisplayState.setPinOrder(PinOrder.move(order, id, delta)) }
    readonly property bool full: pinnedButtons.length >= maxButtons

    function pinned(id) { return DisplayState.pins.indexOf(id) >= 0 }
    function canPin(id) { return pinned(id) || isSlider(id) || !full }
    function setPinned(id, on) {
        const rest = DisplayState.pins.filter(p => p !== id)
        if (on && !canPin(id)) return
        // Congela el orden actual la primera vez, para que reactivar no lo mueva al final.
        if (DisplayState.pinOrder.length === 0) DisplayState.pinOrder = order.slice()
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
        DisplayState.setPinOrder(DisplayState.pinOrder.filter(p => p !== id))
    }
    function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }
}
