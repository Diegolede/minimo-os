// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import "../Common"

// Botón circular gris claro con icono de línea y etiqueta gris debajo.
// Si `confirm` es true, el primer clic lo pone negro ("Confirmar").
Item {
    id: btn
    property string icon
    property string label
    property bool confirm: false
    property bool armed: false
    property bool active: false        // estado "encendido": negro con icono blanco
    property string letter: ""         // accesos propios: inicial en lugar de icono
    signal activated()

    width: 80; height: 80

    Rectangle {
        id: circle
        anchors.horizontalCenter: parent.horizontalCenter
        width: 52; height: 52; radius: 26
        color: (btn.armed || btn.active) ? Theme.fill : (mouse.containsMouse ? Theme.hover : Theme.surface)
        border.width: (btn.armed || btn.active) ? 0 : 1; border.color: Theme.surfaceBorder
        scale: mouse.pressed ? 0.92 : 1
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
        Icon { anchors.centerIn: parent; name: btn.icon; visible: btn.letter === ""; size: 22; tone: (btn.armed || btn.active) ? "white" : "dark" }
        Text {
            anchors.centerIn: parent
            visible: btn.letter !== ""
            text: btn.letter
            color: (btn.armed || btn.active) ? Theme.onAccent : Theme.textPrimary
            font.family: Theme.font; font.pixelSize: 19; font.weight: Font.Medium
        }
    }
    Text {
        anchors.top: circle.bottom; anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        width: btn.width - 4
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: btn.armed ? "Confirmar" : btn.label
        color: (btn.armed || btn.active) ? Theme.textPrimary : Theme.textSecondary
        font.family: Theme.font; font.pixelSize: 11; font.weight: (btn.armed || btn.active) ? Font.DemiBold : Font.Normal
    }

    Timer { id: disarm; interval: 3000; onTriggered: btn.armed = false }

    MouseArea {
        id: mouse
        anchors.fill: circle
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (btn.confirm && !btn.armed) { btn.armed = true; disarm.restart(); return }
            btn.armed = false
            btn.activated()
        }
    }
}
