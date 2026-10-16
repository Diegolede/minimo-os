// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell
import "../../Common"

// Buscador de aplicaciones instaladas (DesktopEntries).
Column {
    id: root
    signal launched()
    property alias query: field.text
    readonly property bool hasFocus: field.activeFocus
    property int selected: 0
    spacing: 4

    function focusField() { field.text = ""; field.forceActiveFocus() }
    function reset() { field.text = ""; field.focus = false }

    readonly property var results: Apps.search(query, 5)
    onResultsChanged: selected = 0

    function launch(entry) { if (entry) { entry.execute(); root.launched() } }

    Rectangle {
        id: box
        width: Math.round(parent.width); height: 40
        radius: height / 2               // píldora
        // Estilo Spotlight: hilo fino semitransparente; con foco, superficie elevada,
        // borde más marcado y un aro suave alrededor (sin blur ni transparencia del panel).
        readonly property bool on: field.activeFocus
        color: on ? Theme.raised : Theme.field
        border.width: 1
        border.color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, on ? 0.40 : 0.20)
        Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
        antialiasing: true
        Rectangle {
            anchors.fill: parent; anchors.margins: -3
            radius: parent.radius + 3
            color: "transparent"
            border.width: 3
            border.color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.08)
            opacity: box.on ? 1 : 0
            scale: box.on ? 1 : 0.985
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            antialiasing: true
        }
        // Toda la píldora es clicable: un clic en cualquier parte enfoca el campo.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onPressed: field.forceActiveFocus()
            onWheel: w => w.accepted = true
        }
        Icon {
            id: lupa
            x: 16; anchors.verticalCenter: parent.verticalCenter
            name: "search"; tone: "gray"; size: 16
        }
        TextInput {
            id: field
            onTextChanged: if (activeFocus) CharacterBus.typed()
            onActiveFocusChanged: if (!activeFocus) CharacterBus.typingStopped()
            cursorVisible: activeFocus
            anchors.left: lupa.right; anchors.leftMargin: 8
            anchors.right: parent.right; anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.textPrimary
            selectionColor: Theme.hover
            selectedTextColor: Theme.textPrimary
            // El cursor "|" solo se dibuja cuando el buscador tiene el foco.
            cursorDelegate: Rectangle { width: 2; radius: 1; color: Theme.textPrimary; visible: field.activeFocus && field.cursorVisible }
            font.family: Theme.font; font.pixelSize: 14
            clip: true
            Text {
                visible: !field.text
                text: I18n.tr("Buscar")
                color: Theme.textSecondary
                font: field.font
            }
            Keys.onDownPressed: root.selected = Math.min(root.selected + 1, root.results.length - 1)
            Keys.onUpPressed: root.selected = Math.max(root.selected - 1, 0)
            onAccepted: root.launch(root.results[root.selected])
        }
    }

    Repeater {
        model: root.results
        delegate: Rectangle {
            required property var modelData
            required property int index
            width: root.width; height: 40; radius: height / 2      // píldora, como el campo y el lanzador
            color: index === root.selected || hov.containsMouse ? Theme.field : "transparent"
            Image {
                id: ic
                x: 12; anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 24
                sourceSize: Qt.size(48, 48)
                source: Apps.iconFor(modelData)
            }
            Text {
                anchors.left: ic.right; anchors.leftMargin: 12
                anchors.right: parent.right; anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: modelData.name
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13
            }
            MouseArea {
                id: hov
                anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.launch(modelData)
                onWheel: w => w.accepted = true   // no cambiar de workspace sobre la lista
            }
        }
    }
}
