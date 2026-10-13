// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
// Vista previa sin Quickshell ni greetd:  qml6 greeter/preview.qml   (login de mentira: "minimo")
// Con PREVIEW_SHOT=ruta.png guarda una captura y sale (PREVIEW_TYPING=1: estado escribiendo).
import QtQuick
import QtQuick.Window
import "Common"

Window {
    id: w
    width: 1280; height: 800; visible: true; flags: Qt.FramelessWindowHint; title: "Minimo OS — inicio (vista previa)"
    readonly property string shot: Qt.application.arguments.find(a => a.endsWith(".png")) || ""
    readonly property bool hold: Qt.application.arguments.indexOf("--hold") >= 0    // no capturar (captura externa)
    readonly property bool typing: Qt.application.arguments.indexOf("--typing") >= 0
    readonly property bool dark: Qt.application.arguments.indexOf("--dark") >= 0
    Component.onCompleted: Theme.dark = dark
    Login {
        id: login
        anchors.fill: parent
        user: "Diego"
        onSubmit: pw => { if (pw === "minimo") Qt.quit(); else { error = "Contraseña incorrecta"; shake() } }
    }
    Timer {
        running: w.shot !== "" || w.hold; interval: 900
        onTriggered: {
            if (w.typing) { login.password = "minimo"; CharacterBus.typed() }
            else Cursor.move(w.width * 0.78, w.height * 0.2)     // mirar hacia arriba a la derecha
            if (!w.hold) grab.start()
        }
    }
    // en la vista "escribiendo" seguimos tecleando para mantener el entrecierre
    Timer { running: w.typing; interval: 300; repeat: true; onTriggered: CharacterBus.typed() }
    Timer { id: grab; interval: 700; function start() { restart() }
        onTriggered: login.grabToImage(r => { r.saveToFile(w.shot); Qt.quit() }) }
}
