// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import "Common"
import "Character"

// Pantalla de inicio de Minimo OS: blanca, Minimo (el personaje real de la shell), hora,
// usuario y una píldora para la contraseña. Sin lógica de greetd: la pone quien la usa
// (shell.qml con Quickshell.Services.Greetd, o preview.qml con un login de mentira).
Rectangle {
    id: root
    property string user: "usuario"
    property string error: ""
    property bool busy: false
    property alias password: field.text
    property alias character: minimo
    property string prompt: ""          // pedido extra de PAM (si lo hay) en lugar de "Contraseña"
    property bool secret: true
    function focusField() { field.forceActiveFocus() }
    // Foco en la contraseña apenas aparece la ventana (cage la activa al mapearla)
    Component.onCompleted: focusTimer.start()
    Timer { id: focusTimer; interval: 50; onTriggered: field.forceActiveFocus() }
    Connections { target: root.Window.window; ignoreUnknownSignals: true
        function onActiveChanged() { if (root.Window.window.active) field.forceActiveFocus() } }
    signal submit(string password)
    function shake() { shakeAnim.restart(); field.text = ""; CharacterBus.react("startled"); field.forceActiveFocus() }

    color: Theme.pick("#FFFFFF", "#0A0A0B")
    Behavior on color { ColorAnimation { duration: 250 } }

    // Los ojos siguen al mouse en toda la pantalla
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: m => Cursor.move(m.x, m.y)
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -root.height * 0.04
        spacing: 0

        Text {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: Theme.font; font.pixelSize: 84; font.weight: Font.DemiBold
            font.letterSpacing: -2
            color: Theme.textPrimary
            text: Qt.formatTime(new Date(), "HH:mm")
            Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.text = Qt.formatTime(new Date(), "HH:mm") }
        }
        Text {
            id: date
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: Theme.font; font.pixelSize: 17
            color: Theme.textSecondary
            text: { const s = Qt.locale("es_AR").toString(new Date(), "dddd d 'de' MMMM"); return s.charAt(0).toUpperCase() + s.slice(1) }
        }
        Item { width: 1; height: 64 }
        Character {
            id: minimo
            anchors.horizontalCenter: parent.horizontalCenter
            size: 112
        }
        Item { width: 1; height: 26 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: Theme.font; font.pixelSize: 20; font.weight: Font.DemiBold
            color: Theme.textPrimary
            text: root.user
        }
        Item { width: 1; height: 18 }

        // Píldora de contraseña
        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            width: 280; height: 44; radius: 22
            color: Theme.field
            border.width: field.activeFocus ? 1.5 : 0
            border.color: Theme.track
            transform: Translate { id: shakeT }
            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: shakeT; property: "x"; to: -10; duration: 50 }
                NumberAnimation { target: shakeT; property: "x"; to: 9; duration: 70 }
                NumberAnimation { target: shakeT; property: "x"; to: -6; duration: 70 }
                NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 80 }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onPressed: field.forceActiveFocus() }
            Text {
                anchors.centerIn: parent
                visible: field.text.length === 0
                font.family: Theme.font; font.pixelSize: 15
                color: Theme.textSecondary
                text: root.busy ? "Entrando…" : (root.prompt || "Contraseña")
            }
            TextInput {
                id: field
                anchors.fill: parent
                anchors.leftMargin: 20; anchors.rightMargin: 48
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                echoMode: root.secret ? TextInput.Password : TextInput.Normal
                passwordCharacter: "•"
                font.family: Theme.font; font.pixelSize: 17; font.letterSpacing: 2
                color: Theme.textPrimary
                enabled: !root.busy
                focus: true
                // Minimo entrecierra los ojos mientras escribís (igual que en la isla)
                onTextChanged: { root.error = ""; if (activeFocus) CharacterBus.typed() }
                onActiveFocusChanged: if (!activeFocus) CharacterBus.typingStopped()
                onAccepted: if (text.length && !root.busy) root.submit(text)
            }
            // Botón entrar: círculo con flecha (sin íconos externos)
            Rectangle {
                width: 32; height: 32; radius: 16
                anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                color: field.text.length ? Theme.fill : Theme.track
                Behavior on color { ColorAnimation { duration: 160 } }
                // flecha dibujada: tallo + punta (dos trazos redondeados)
                Item {
                    anchors.centerIn: parent; width: 14; height: 14
                    Rectangle { width: 12; height: 2; radius: 1; x: 1; y: 6; color: field.text.length ? Theme.onAccent : Theme.textSecondary; antialiasing: true }
                    Rectangle { width: 7; height: 2; radius: 1; x: 6.5; y: 3.6; rotation: 45; color: field.text.length ? Theme.onAccent : Theme.textSecondary; antialiasing: true }
                    Rectangle { width: 7; height: 2; radius: 1; x: 6.5; y: 8.4; rotation: -45; color: field.text.length ? Theme.onAccent : Theme.textSecondary; antialiasing: true }
                }
                MouseArea { anchors.fill: parent; enabled: field.text.length && !root.busy; onClicked: root.submit(field.text) }
            }
        }
        Item { width: 1; height: 14 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: Theme.font; font.pixelSize: 13
            color: Theme.danger
            opacity: root.error ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
            text: root.error || " "
        }
    }

    Text {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 28
        anchors.horizontalCenter: parent.horizontalCenter
        font.family: Theme.font; font.pixelSize: 12; font.letterSpacing: 3
        color: Theme.textSecondary
        text: "MINIMO OS"
    }
}
