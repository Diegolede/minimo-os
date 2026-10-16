// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import "Common"

// Selector de sesión, discreto abajo a la izquierda: muestra la elegida; al tocarlo se
// abre una lista hacia arriba. Solo aparece si hay más de una sesión.
Item {
    id: root
    property var sessions: []          // [{ id, name }]
    property string current: ""
    property bool open: false
    signal picked(string id)
    visible: sessions.length > 1
    width: Math.max(btn.width, menu.width); height: btn.height
    readonly property string currentName: (sessions.find(s => s.id === current) ?? { name: "" }).name

    Rectangle {
        id: btn
        width: label.implicitWidth + 28; height: 34; radius: 17
        color: bm.containsMouse || root.open ? Theme.field : "transparent"
        Behavior on color { ColorAnimation { duration: 160 } }
        Text {
            id: label
            anchors.centerIn: parent
            text: root.currentName
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12
        }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.open = !root.open }
    }

    Rectangle {
        id: menu
        anchors.bottom: btn.top; anchors.bottomMargin: 8
        width: Math.max(200, list.implicitWidth); height: list.implicitHeight + 12; radius: 18
        color: Theme.cardSolid; border.width: 1; border.color: Theme.track
        opacity: root.open ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Column {
            id: list
            x: 6; y: 6
            Repeater {
                model: root.sessions
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    width: Math.max(188, rowText.implicitWidth + 48); height: 34; radius: 12
                    color: rm.containsMouse ? Theme.hover : "transparent"
                    Text {
                        id: rowText
                        x: 14; anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.name
                        color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13
                        font.weight: row.modelData.id === root.current ? Font.DemiBold : Font.Normal
                    }
                    // Marca de la elegida: punto negro (sin iconos externos en el greeter).
                    Rectangle {
                        visible: row.modelData.id === root.current
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                        width: 6; height: 6; radius: 3; color: Theme.fill
                    }
                    MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { root.open = false; root.picked(row.modelData.id) } }
                }
            }
        }
    }
}
