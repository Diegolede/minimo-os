// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import "../../Common"
import ".."

// Elementos fijados del menú (Ajustes › Personalización › Menú de la isla):
// controles deslizantes arriba y botones en filas de 4 (como máximo 3 filas).
Column {
    id: root
    signal done()
    signal desktops()
    spacing: 18

    readonly property var sliders: QuickItems.pinnedSliders
    readonly property var buttons: QuickItems.pinnedButtons
    readonly property string shotCmd: 'd="$HOME/Imágenes/Capturas"; mkdir -p "$d"; g=$(slurp) || exit 0; grim -g "$g" "$d/captura-$(date +%Y%m%d-%H%M%S).png"'

    function activate(id) {
        if (id === "terminal") { QuickItems.run("ghostty"); root.done() }
        // Grabar: cierra la isla y arranca a los 0,4 s (para no grabarla abierta).
        else if (id === "record") { if (Recorder.recording) Recorder.stop(); else Recorder.start(400); root.done() }
        else if (id === "capture") { QuickItems.run("sleep 0.3; " + root.shotCmd); root.done() }
        else if (id === "desktops") root.desktops()
        else { const c = QuickItems.custom(id); if (c) { QuickItems.run(c.cmd); root.done() } }
    }

    Column {
        width: parent.width
        spacing: 8
        visible: root.sliders.length > 0
        // El orden de los deslizadores sigue el del catálogo (volumen, brillo, saturación).
        VolumeSection { width: parent.width; visible: ready && root.sliders.indexOf("volume") >= 0 }
        DisplaySection {
            width: parent.width
            visible: brightness || vibrance
            brightness: root.sliders.indexOf("brightness") >= 0
            vibrance: root.sliders.indexOf("vibrance") >= 0
        }
    }

    Grid {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.buttons.length > 0
        columns: QuickItems.columns
        rowSpacing: 4
        Repeater {
            model: root.buttons
            delegate: MenuButton {
                id: b
                required property string modelData
                readonly property var item: QuickItems.builtins.find(x => x.id === modelData) ?? QuickItems.custom(modelData)
                readonly property bool rec: modelData === "record" && Recorder.recording
                icon: rec ? "stop" : (item && item.icon ? item.icon : "")
                letter: item && !item.icon ? item.label.charAt(0).toUpperCase() : ""
                label: rec ? "Detener" : modelData === "record" ? "Grabar" : (item ? item.label : "")
                active: rec
                onActivated: root.activate(b.modelData)
            }
        }
    }
}
