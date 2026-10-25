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
    // Teclado: el botón se hunde al presionar y dispara al soltar (igual que con el mouse).
    property bool keyDown: false
    Keys.onPressed: e => { if (!e.isAutoRepeat && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)) { keyDown = true; e.accepted = true } }
    Keys.onReleased: e => { if (!e.isAutoRepeat && keyDown && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)) { keyDown = false; mouse.fire(); e.accepted = true } }
    onActiveFocusChanged: if (!activeFocus) keyDown = false

    Rectangle {
        id: circle
        anchors.horizontalCenter: parent.horizontalCenter
        width: 52; height: 52; radius: 26
        color: (btn.isArmed || btn.active) ? Theme.fill : (mouse.containsMouse ? Theme.hover : Theme.surface)
        scale: (mouse.pressed && mouse.containsMouse) || btn.keyDown ? 0.92 : 1
        Rectangle {          // aro de foco por teclado (solo con foco)
            anchors.fill: parent; anchors.margins: -4; radius: width / 2
            color: "transparent"; border.width: 2; border.color: Theme.fill
            // Aparece suave (sin "pop") al llegar con Tab.
            opacity: btn.activeFocus ? 1 : 0
            scale: btn.activeFocus ? 1 : 0.94
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
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
        // Al pasar el mouse la etiqueta se oscurece: queda claro qué botón se va a tocar.
        color: (btn.isArmed || btn.active || mouse.containsMouse) ? Theme.textPrimary : Theme.textSecondary
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        font.family: Theme.font; font.pixelSize: 11; font.weight: (btn.isArmed || btn.active) ? Font.DemiBold : Font.Normal
    }

    Timer { id: disarm; interval: 3000; onTriggered: btn.selfArmed = false }

    MouseArea {
        id: mouse
        // Toda la celda (círculo + etiqueta) es clicable: más fácil de acertar.
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function fire() {
            if (btn.confirm && !btn.selfArmed) { btn.selfArmed = true; disarm.restart(); return }
            btn.selfArmed = false; disarm.stop()
            btn.activated()
        }
        // Si se arrastra afuera antes de soltar, no dispara (permite arrepentirse).
        onClicked: if (containsMouse) fire()
    }
}
