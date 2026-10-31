// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick

// Interruptor estilo iOS (negro encendido, gris apagado).
Item {
    id: sw
    property bool checked: false
    property bool enabled: true
    signal toggled(bool value)
    width: 46; height: Theme.controlH - 4
    activeFocusOnTab: enabled
    opacity: enabled ? 1 : 0.45
    Keys.onPressed: e => {
        if (!enabled) return
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
            sw.toggled(!sw.checked); e.accepted = true
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: sw.checked ? Theme.fill : Theme.track
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        // Aro de foco por teclado
        Rectangle {
            anchors.fill: parent; anchors.margins: -3; radius: height / 2
            color: "transparent"; border.width: 2; border.color: Theme.fill
            opacity: sw.activeFocus ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        }
        Rectangle {
            width: 22; height: 22; radius: 11
            y: (parent.height - height) / 2
            x: sw.checked ? parent.width - width - 3 : 3
            color: sw.checked ? Theme.onAccent : "#FFFFFF"
            Behavior on x { NumberAnimation { duration: Theme.reduceMotion ? 0 : 180; easing.type: Easing.OutCubic } }
        }
    }
    // Área clicable ampliada (≥ hitMin en altura táctil)
    MouseArea {
        anchors.fill: parent
        anchors.margins: -((Theme.hitMin - parent.height) / 2)
        enabled: sw.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled(!sw.checked)
    }
}
