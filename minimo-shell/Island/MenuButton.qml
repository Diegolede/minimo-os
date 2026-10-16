// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import "../Common"

// Botón circular gris claro con icono de línea y etiqueta gris debajo.
// Sin filete: el círculo se distingue por icono, etiqueta y hover. El foco por teclado se
// muestra con un aro solo mientras hay foco (Tab), nunca como borde permanente.
// `armed` puede venir de afuera (máquina de estados de ActionsSection) y se respeta;
// si `confirm` es true, el botón usa su propio estado interno (`selfArmed`). El clic nunca
// escribe `armed`, así no rompe el binding externo (eso apagaba el negro de confirmación).
Item {
    id: btn
    property string icon
    property string label
    property bool confirm: false
    property bool armed: false         // armado desde afuera (binding)
    property bool selfArmed: false     // armado interno (confirm: true)
    readonly property bool isArmed: armed || selfArmed
    property bool active: false        // estado "encendido": negro con icono blanco
    property string letter: ""         // accesos propios: inicial en lugar de icono
    signal activated()

    width: 80; height: 80
    activeFocusOnTab: true
    Keys.onReturnPressed: mouse.fire()
    Keys.onSpacePressed: mouse.fire()

    Rectangle {
        id: circle
        anchors.horizontalCenter: parent.horizontalCenter
        width: 52; height: 52; radius: 26
        color: (btn.isArmed || btn.active) ? Theme.fill : (mouse.containsMouse ? Theme.hover : Theme.surface)
        scale: mouse.pressed ? 0.92 : 1
        Rectangle {          // aro de foco por teclado (solo con foco)
            anchors.fill: parent; anchors.margins: -4; radius: width / 2
            color: "transparent"; border.width: 2; border.color: Theme.fill
            visible: btn.activeFocus
        }
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
        Icon { anchors.centerIn: parent; name: btn.icon; visible: btn.letter === ""; size: 22; tone: (btn.isArmed || btn.active) ? "white" : "dark" }
        Text {
            anchors.centerIn: parent
            visible: btn.letter !== ""
            text: btn.letter
            color: (btn.isArmed || btn.active) ? Theme.onAccent : Theme.textPrimary
            font.family: Theme.font; font.pixelSize: 19; font.weight: Font.Medium
        }
    }
    Text {
        anchors.top: circle.bottom; anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        width: btn.width - 4
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: btn.isArmed ? I18n.tr("Confirmar") : btn.label
        color: (btn.isArmed || btn.active) ? Theme.textPrimary : Theme.textSecondary
        font.family: Theme.font; font.pixelSize: 11; font.weight: (btn.isArmed || btn.active) ? Font.DemiBold : Font.Normal
    }

    Timer { id: disarm; interval: 3000; onTriggered: btn.selfArmed = false }

    MouseArea {
        id: mouse
        anchors.fill: circle
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function fire() {
            if (btn.confirm && !btn.selfArmed) { btn.selfArmed = true; disarm.restart(); return }
            btn.selfArmed = false; disarm.stop()
            btn.activated()
        }
        onClicked: fire()
    }
}
