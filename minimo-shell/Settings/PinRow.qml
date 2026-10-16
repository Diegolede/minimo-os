// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import "../Common"

// Fila del editor del menú: icono (o inicial), nombre, detalle y fijar/quitar.
// Los accesos propios muestran además "Eliminar" (confirmación en dos clics).
Item {
    id: row
    property string icon
    property string text
    property string detail
    property bool pinned
    property bool canPin: true
    property bool removable: false
    property bool last: false
    property bool armed: false
    property bool canUp: false
    property bool canDown: false
    signal toggled(bool v)
    signal moveRequested(int delta)
    signal removeRequested()
    implicitHeight: 56

    Rectangle {
        id: badge
        x: 16; anchors.verticalCenter: parent.verticalCenter
        width: 32; height: 32; radius: 16
        color: Theme.field
        Icon { anchors.centerIn: parent; visible: row.icon !== ""; name: row.icon; size: 16; tone: "dark" }
        Text {
            anchors.centerIn: parent; visible: row.icon === ""
            text: row.text.charAt(0).toUpperCase()
            color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold
        }
    }
    Column {
        anchors.left: badge.right; anchors.leftMargin: 12
        anchors.right: controls.left; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Text { width: parent.width; text: row.text; elide: Text.ElideRight; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 14 }
        Text {
            width: parent.width; visible: text !== ""; elide: Text.ElideMiddle
            text: row.detail
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12
        }
    }
    Row {
        id: controls
        anchors.right: parent.right; anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
        // Reordenar: subir / bajar (deshabilitado en los extremos).
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Repeater {
                model: [-1, 1]
                delegate: Rectangle {
                    id: mv
                    required property int modelData
                    readonly property bool ok: modelData < 0 ? row.canUp : row.canDown
                    width: 28; height: 28; radius: 14
                    color: mvm.containsMouse && ok ? Theme.hover : "transparent"
                    opacity: ok ? 1 : 0.3
                    Icon { anchors.centerIn: parent; name: "chevron"; size: 16; tone: "dark"; rotation: mv.modelData < 0 ? 180 : 0 }
                    MouseArea {
                        id: mvm; anchors.fill: parent; hoverEnabled: true
                        enabled: mv.ok; cursorShape: Qt.PointingHandCursor
                        onClicked: row.moveRequested(mv.modelData)
                    }
                }
            }
        }
        Rectangle {
            visible: row.removable
            anchors.verticalCenter: parent.verticalCenter
            width: rl.implicitWidth + 24; height: 28; radius: 14
            color: row.armed ? Theme.danger : (rm.containsMouse ? Theme.hover : Theme.surface)
            border.width: row.armed ? 0 : 1; border.color: Theme.surfaceBorder
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
            Text { id: rl; anchors.centerIn: parent; text: row.armed ? "Confirmar" : "Eliminar"; color: row.armed ? "#FFFFFF" : Theme.textPrimary; font.family: Theme.font; font.pixelSize: 12; font.weight: row.armed ? Font.DemiBold : Font.Normal }
            MouseArea {
                id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { if (!row.armed) { row.armed = true; disarm.restart() } else { row.armed = false; row.removeRequested() } }
            }
        }
        MSwitch {
            anchors.verticalCenter: parent.verticalCenter
            checked: row.pinned
            enabled: row.pinned || row.canPin
            opacity: enabled ? 1 : 0.4
            onToggled: v => row.toggled(v)
        }
    }
    Timer { id: disarm; interval: 3000; onTriggered: row.armed = false }
    Rectangle { visible: !row.last; anchors.bottom: parent.bottom; x: 60; width: parent.width - 60; height: 1; color: Theme.track }
}
