// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../Common"
import ".."

// Elementos fijados del menú (Ajustes › Personalización › Menú de la isla):
// controles deslizantes arriba y botones en filas de 4 (como máximo 3 filas).
Column {
    id: root
    signal done()
    signal desktops()
    signal clipboard()
    signal notes()
    signal emoji()
    spacing: 18

    readonly property var sliders: QuickItems.pinnedSliders
    readonly property var buttons: QuickItems.pinnedButtons
    readonly property string shotScript: Qt.resolvedUrl("../../scripts/screenshot.sh").toString().replace("file://", "")

    function activate(id) {
        if (id === "terminal") { QuickItems.run("ghostty"); root.done() }
        // Grabar: cierra la isla y arranca a los 0,4 s (para no grabarla abierta).
        else if (id === "record") { if (Recorder.recording) Recorder.stop(); else Recorder.start(400); root.done() }
        else if (id === "capture") { Quickshell.execDetached(["sh", "-c", 'sleep 0.3; exec "$0" area', root.shotScript]); root.done() }
        else if (id === "desktops") root.desktops()
        else if (id === "clipboard") root.clipboard()
        else if (id === "notes") root.notes()
        else if (id === "emoji") root.emoji()
        // Navegador / archivos: la isla se cierra solo si se lanzó; si no, aviso en línea.
        else if (id === "browser" || id === "files") Launch.open(id)
        else { const c = QuickItems.custom(id); if (c) { QuickItems.run(c.cmd); root.done() } }
    }

    // Deslizadores en el orden elegido en Ajustes: volumen antes o después del bloque
    // de pantalla (brillo y saturación van juntos en DisplaySection, en ese orden).
    Item {
        id: sl
        width: parent.width
        visible: root.sliders.length > 0
        readonly property int volAt: root.sliders.indexOf("volume")
        readonly property bool volFirst: volAt === 0
        readonly property real volH: vol.visible ? vol.height : 0
        readonly property real dispH: disp.visible ? disp.height : 0
        readonly property real gap: vol.visible && disp.visible ? 8 : 0
        height: volH + dispH + gap
        VolumeSection { id: vol; width: parent.width; visible: ready && sl.volAt >= 0; y: sl.volFirst ? 0 : sl.dispH + sl.gap }
        DisplaySection {
            id: disp
            width: parent.width
            visible: brightness || vibrance
            y: sl.volFirst ? sl.volH + sl.gap : 0
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
                label: rec ? I18n.tr("Detener") : modelData === "record" ? I18n.tr("Grabar") : (item ? item.label : "")
                active: rec
                onActivated: root.activate(b.modelData)
            }
        }
    }

    Connections {
        target: Launch
        function onLaunched() { root.done() }
    }
    // Error al abrir (no bloquea; desaparece solo).
    Text {
        width: parent.width
        visible: Launch.error !== ""
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: Launch.error
        color: Theme.danger; font.family: Theme.font; font.pixelSize: 12
    }
}
