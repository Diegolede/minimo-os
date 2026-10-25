// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick

// Slider estilo Centro de Control: pista gruesa gris, relleno negro, icono adentro.
Item {
    id: s
    property string icon
    property string label
    property real from: 0
    property real to: 1
    property real value: 0
    property string valueText: Math.round(frac * 100) + "%"
    property bool iconClickable: false
    readonly property real frac: Math.max(0, Math.min(1, (value - from) / (to - from)))
    signal moved(real v)
    signal iconClicked()

    implicitHeight: 40
    implicitWidth: 320

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Theme.track
        clip: true
        Rectangle {
            id: fillRect
            height: parent.height
            width: Math.max(parent.height, parent.width * s.frac)
            radius: height / 2
            color: Theme.fill
            Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
    }
    MouseArea {
        id: drag
        anchors.fill: parent
        anchors.leftMargin: s.iconClickable ? 40 : 0
        cursorShape: Qt.PointingHandCursor
        function upd(mx) {
            const f = Math.max(0, Math.min(1, (mx + anchors.leftMargin) / s.width))
            s.moved(s.from + f * (s.to - s.from))
        }
        onPressed: m => upd(m.x)
        onPositionChanged: m => { if (pressed) upd(m.x) }
        // Rueda: 5% por muesca. Los deltas chicos del touchpad se acumulan (no saltan de a 5%).
        property real acc: 0
        onWheel: w => {
            acc += w.angleDelta.y
            const steps = acc > 0 ? Math.floor(acc / 120) : Math.ceil(acc / 120)
            if (steps === 0) return
            acc -= steps * 120
            s.moved(Math.max(s.from, Math.min(s.to, s.value + steps * (s.to - s.from) * 0.05)))
        }
    }
    Icon {
        x: 12; anchors.verticalCenter: parent.verticalCenter
        size: 18
        name: s.icon
        tone: fillRect.width > 36 ? "white" : "dark"
        // Icono clicable (silenciar): se atenúa al pasar y se hunde al presionar.
        opacity: iconMouse.pressed ? 0.55 : iconMouse.containsMouse ? 0.75 : 1
        scale: iconMouse.pressed ? 0.9 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
        MouseArea {
            id: iconMouse
            anchors.fill: parent; anchors.margins: -10
            enabled: s.iconClickable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: s.iconClicked()
        }
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        id: valueLabel
        text: s.valueText
        // El color sigue al relleno: blanco solo cuando el negro ya pasa por debajo del número
        // (antes quedaba gris sobre negro entre ~80% y 90%).
        color: fillRect.width > x + width / 2 ? Theme.onAccent : Theme.textSecondary
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium
        font.features: { "tnum": 1 }
    }
}
