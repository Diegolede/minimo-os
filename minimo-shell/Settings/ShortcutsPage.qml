// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../Common"

// Atajos de teclado: se generan desde la configuración real (hypr/minimo/atajos.lua y hypr/minimo.lua)
// con scripts/atajos.py. Se leen una vez al abrir la página (sin sondeos) y se
// pueden filtrar escribiendo.
Column {
    id: root
    spacing: 20
    property bool shown: false
    property var groups: []
    property bool failed: false
    property alias filter: input.text

    readonly property string script: Qt.resolvedUrl("../scripts/atajos.py").toString().replace("file://", "")
    function refresh() { reader.running = false; reader.running = true }
    onShownChanged: if (shown) refresh()

    Process {
        id: reader
        command: ["python3", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    root.groups = d.groups || []
                    root.failed = !!d.error || root.groups.length === 0
                } catch (e) { root.groups = []; root.failed = true }
            }
        }
    }

    function matches(item) {
        const f = root.filter.trim().toLowerCase()
        if (!f) return true
        if (item.label.toLowerCase().indexOf(f) >= 0) return true
        return item.combos.some(c => c.mods.concat(c.keys).join(" ").toLowerCase().indexOf(f) >= 0)
    }
    readonly property var shownGroups: groups.map(g => ({ name: g.name, items: g.items.filter(i => matches(i)) })).filter(g => g.items.length > 0)

    // Buscador.
    Rectangle {
        width: parent.width; height: 40; radius: 20
        color: Theme.field
        Icon { id: mag; name: "search"; size: 16; tone: "gray"; x: 14; anchors.verticalCenter: parent.verticalCenter }
        TextInput {
            id: input
            anchors.left: mag.right; anchors.leftMargin: 10
            anchors.right: parent.right; anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 14
            selectByMouse: true; clip: true
            Keys.onEscapePressed: event => { if (text) { text = ""; event.accepted = true } else event.accepted = false }
        }
        Text {
            anchors.fill: input; verticalAlignment: Text.AlignVCenter
            visible: !input.text
            text: "Buscar atajo o tecla"; color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 14
        }
    }

    Text {
        visible: root.failed || (root.groups.length > 0 && root.shownGroups.length === 0)
        width: parent.width
        wrapMode: Text.WordWrap
        text: root.failed ? "No se pudieron leer los atajos (hace falta lua y python)." : "Ningún atajo coincide."
        color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 13
    }

    Repeater {
        model: root.shownGroups
        delegate: Column {
            id: group
            required property var modelData
            width: root.width
            spacing: 8
            SectionTitle { text: group.modelData.name }
            Rectangle {
                width: parent.width
                height: list.implicitHeight
                radius: 20
                color: Theme.field
                Column {
                    id: list
                    width: parent.width
                    Repeater {
                        model: group.modelData.items
                        delegate: ShortcutRow {
                            required property var modelData
                            required property int index
                            width: list.width
                            label: modelData.label
                            combos: modelData.combos
                            last: index === group.modelData.items.length - 1
                        }
                    }
                }
            }
        }
    }

    Text {
        visible: !root.failed && root.groups.length > 0
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Se editan en ~/.config/hypr/minimo/atajos.lua. Los cambios se ven al volver a abrir esta página."
        color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12
    }
}
