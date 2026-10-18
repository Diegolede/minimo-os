// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import "Common"
import "Character"
import "Island"

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
    signal cancelled()                  // Escape: borra y cancela un pedido extra de PAM
    signal outroDone()                  // terminó la salida tras un login correcto
    signal powerOff()
    signal reboot()
    property var sessions: []           // [{ id, name }] (selector abajo a la izquierda)
    property string session: ""
    signal sessionPicked(string id)
    property bool reveal: false         // mostrar la contraseña (ojo)
    property bool caps: false           // Bloq Mayús (deducido de lo que se escribe)
    property int idleMs: 60000          // Minimo se duerme tras 1 min sin actividad

    // ===== Actividad y sueño =====
    function activity() { idleTimer.restart(); if (IdleState.sleeping) IdleState.wake() }
    Timer { id: idleTimer; interval: root.idleMs; running: true; onTriggered: if (!root.busy && field.text === "") IdleState.sleepNow() }

    // ===== Entrada y salida suaves =====
    // Entrada: el contenido aparece con un fundido y una escala mínima (sin saltos).
    // Salida (login correcto): Minimo guiña, luego todo se desvanece a blanco y recién ahí
    // se lanza la sesión, para que no haya un corte brusco.
    function succeed() {
        root.busy = true; idleTimer.stop(); IdleState.wake()
        CharacterBus.react("wink")
        outro.start()
    }
    SequentialAnimation {
        id: outro
        PauseAnimation { duration: 750 }
        ParallelAnimation {
            NumberAnimation { target: stage; property: "opacity"; to: 0; duration: 420; easing.type: Easing.InCubic }
            NumberAnimation { target: stage; property: "scale"; to: 0.97; duration: 420; easing.type: Easing.InCubic }
        }
        ScriptAction { script: root.outroDone() }
    }
    function shake() { shakeAnim.restart(); field.text = ""; CharacterBus.react("startled"); field.forceActiveFocus() }

    color: Theme.pick("#FFFFFF", "#0A0A0B")
    Behavior on color { ColorAnimation { duration: 250 } }

    // Los ojos siguen al mouse en toda la pantalla
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: m => { Cursor.move(m.x, m.y); root.activity() }
    }

    Item {
    id: stage
    anchors.fill: parent
    opacity: 0; scale: 0.985
    Component.onCompleted: intro.start()
    ParallelAnimation {
        id: intro
        NumberAnimation { target: stage; property: "opacity"; to: 1; duration: 520; easing.type: Easing.OutCubic }
        NumberAnimation { target: stage; property: "scale"; to: 1; duration: 620; easing.type: Easing.OutCubic }
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
            // Z z z de la isla mientras duerme
            Zzz { running: IdleState.sleeping; x: parent.width * 0.86; y: -parent.height * 0.28; scale: 1.6; transformOrigin: Item.BottomLeft }
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
                id: placeholder
                anchors.centerIn: parent
                visible: field.text.length === 0 && !root.busy
                font.family: Theme.font; font.pixelSize: 15
                color: Theme.textSecondary
                text: root.prompt || "Contraseña"
            }
            // Cursor con el campo vacío: barra fina justo antes de "Contraseña" (el texto queda
            // centrado y el cursor real caería encima). Parpadea solo con foco.
            Rectangle {
                id: emptyCaret
                visible: field.activeFocus && field.text.length === 0 && !root.busy
                x: placeholder.x - width - 4; anchors.verticalCenter: parent.verticalCenter
                width: 2; height: 20; radius: 1
                color: Theme.textPrimary
                SequentialAnimation on opacity {
                    running: emptyCaret.visible; loops: Animation.Infinite
                    PropertyAction { value: 1 }
                    PauseAnimation { duration: 530 }
                    PropertyAction { value: 0 }
                    PauseAnimation { duration: 530 }
                    onStopped: emptyCaret.opacity = 1
                }
            }
            // Cargando: tres puntos que respiran mientras greetd verifica
            Row {
                anchors.centerIn: parent
                spacing: 7
                visible: root.busy
                Repeater {
                    model: 3
                    Rectangle {
                        id: dot
                        required property int index
                        width: 7; height: 7; radius: 3.5
                        color: Theme.textSecondary
                        SequentialAnimation on opacity {
                            running: root.busy; loops: Animation.Infinite
                            PauseAnimation { duration: dot.index * 160 }
                            NumberAnimation { to: 1; duration: 320; easing.type: Easing.OutSine }
                            NumberAnimation { to: 0.25; duration: 420; easing.type: Easing.InSine }
                            PauseAnimation { duration: (2 - dot.index) * 160 }
                        }
                    }
                }
            }
            TextInput {
                id: field
                anchors.fill: parent
                anchors.leftMargin: 76; anchors.rightMargin: 76
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                echoMode: root.secret && !root.reveal ? TextInput.Password : TextInput.Normal
                opacity: root.busy ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 160 } }
                passwordCharacter: "•"
                // Cursor propio (2 px, color del texto: contraste alto en claro y oscuro). Vacío: lo
                // dibuja emptyCaret junto a "Contraseña"; con texto, este, al final de los puntos.
                cursorVisible: activeFocus && text.length > 0
                cursorDelegate: Rectangle {
                    id: caret
                    width: 2; radius: 1
                    color: Theme.textPrimary
                    visible: field.cursorVisible
                    SequentialAnimation on opacity {
                        running: caret.visible; loops: Animation.Infinite
                        PropertyAction { value: 1 }
                        PauseAnimation { duration: 530 }
                        PropertyAction { value: 0 }
                        PauseAnimation { duration: 530 }
                        onStopped: caret.opacity = 1
                    }
                }
                font.family: Theme.font; font.pixelSize: 17; font.letterSpacing: 2
                color: Theme.textPrimary
                enabled: !root.busy
                focus: true
                // Minimo entrecierra los ojos mientras escribís (igual que en la isla)
                onTextChanged: { root.error = ""; if (activeFocus) CharacterBus.typed() }
                onActiveFocusChanged: if (!activeFocus) CharacterBus.typingStopped()
                onAccepted: if (text.length && !root.busy) root.submit(text)
                Keys.onPressed: e => {
                    root.activity()
                    if (e.key === Qt.Key_Escape) { text = ""; root.reveal = false; root.cancelled(); e.accepted = true; return }
                    // Bloq Mayús: letra en mayúscula sin Shift (o al revés)
                    const t = e.text
                    if (t.length === 1 && t.toLowerCase() !== t.toUpperCase()) {
                        const upper = t === t.toUpperCase(), shift = (e.modifiers & Qt.ShiftModifier) !== 0
                        root.caps = upper !== shift
                    }
                    if (e.key === Qt.Key_CapsLock) root.caps = !root.caps
                }
            }
            // Mostrar/ocultar contraseña: ojo dibujado (contorno almendrado + pupila; tachado si oculta)
            Item {
                id: eyeBtn
                visible: root.secret && field.text.length > 0 && !root.busy
                width: 32; height: 32
                anchors.right: parent.right; anchors.rightMargin: 42; anchors.verticalCenter: parent.verticalCenter
                opacity: eyeMa.containsMouse ? 1 : 0.7
                Icon { anchors.centerIn: parent; name: root.reveal ? "eye" : "eye-off"; size: 18; tone: "gray" }
                MouseArea { id: eyeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.reveal = !root.reveal; field.forceActiveFocus() } }
            }
            // Botón entrar: círculo con flecha (Fluent Arrow Right)
            Rectangle {
                width: 32; height: 32; radius: 16
                anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                color: field.text.length ? Theme.fill : Theme.track
                Behavior on color { ColorAnimation { duration: 160 } }
                Icon { anchors.centerIn: parent; name: "arrow-right"; size: 16; tone: field.text.length ? "white" : "gray" }
                MouseArea { anchors.fill: parent; enabled: field.text.length && !root.busy; onClicked: root.submit(field.text) }
            }
        }
        Item { width: 1; height: 14 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: Theme.font; font.pixelSize: 13
            color: root.error ? Theme.danger : Theme.textSecondary
            opacity: root.error || (root.caps && field.activeFocus) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
            text: root.error || (root.caps ? "Bloq Mayús activado" : " ")
        }
    }

    Text {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 28
        anchors.horizontalCenter: parent.horizontalCenter
        font.family: Theme.font; font.pixelSize: 12; font.letterSpacing: 3
        color: Theme.textSecondary
        text: "MINIMO OS"
    }
    }   // stage

    SessionPicker {
        anchors.left: parent.left; anchors.bottom: parent.bottom
        anchors.leftMargin: 24; anchors.bottomMargin: 20
        opacity: stage.opacity
        enabled: !root.busy
        sessions: root.sessions
        current: root.session
        onPicked: id => { root.activity(); root.sessionPicked(id); root.focusField() }
    }

    // Apagar / reiniciar: discretos abajo a la derecha. Primer clic pide confirmación
    // (la etiqueta aparece), el segundo dentro de 3 s ejecuta.
    Row {
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.rightMargin: 24; anchors.bottomMargin: 20
        spacing: 6
        opacity: stage.opacity
        property string armed: ""
        id: power
        Timer { id: disarm; interval: 3000; onTriggered: power.armed = "" }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            font.family: Theme.font; font.pixelSize: 12
            color: Theme.textSecondary
            opacity: power.armed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
            text: power.armed === "reboot" ? "Reiniciar  " : power.armed === "off" ? "Apagar  " : ""
        }
        Repeater {
            model: ["reboot", "off"]
            Rectangle {
                id: pb
                required property string modelData
                width: 34; height: 34; radius: 17
                color: power.armed === pb.modelData ? Theme.fill : (ma.containsMouse ? Theme.field : "transparent")
                Behavior on color { ColorAnimation { duration: 160 } }
                readonly property color ink: power.armed === pb.modelData ? Theme.onAccent : Theme.textSecondary
                onInkChanged: icon.requestPaint()
                Icon { anchors.centerIn: parent; visible: pb.modelData === "off"; name: "power"; size: 18; tone: power.armed === pb.modelData ? "white" : "gray" }
                Canvas {
                    id: icon
                    visible: pb.modelData !== "off"
                    anchors.centerIn: parent; width: 16; height: 16
                    renderStrategy: Canvas.Cooperative
                    onPaint: {
                        const g = getContext("2d"); g.reset()
                        g.strokeStyle = pb.ink; g.fillStyle = pb.ink; g.lineWidth = 1.7; g.lineCap = "round"
                        g.beginPath()
                        g.arc(8, 8.5, 6, -Math.PI * 0.15, Math.PI * 1.45, false); g.stroke()
                        g.beginPath(); g.moveTo(14.6, 1.8); g.lineTo(14.2, 6.6); g.lineTo(9.6, 5.6); g.stroke()
                    }
                }
                MouseArea {
                    id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.activity()
                        if (power.armed === pb.modelData) { power.armed = ""; pb.modelData === "off" ? root.powerOff() : root.reboot() }
                        else { power.armed = pb.modelData; disarm.restart() }
                    }
                }
            }
        }
    }
}
