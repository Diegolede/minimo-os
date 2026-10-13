// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
// Pantalla de inicio de Minimo OS para greetd (Quickshell). Se lanza dentro de `cage`:
//   cage -s -- qs -p /usr/share/minimo-os/greeter
// Variables: MINIMO_USER (usuario), MINIMO_SESSION (comando, por defecto Hyprland),
//            MINIMO_DARK=1 (modo oscuro), MINIMO_GREETER_TEST=1 (login de mentira).
import QtQuick
import Quickshell
import Quickshell.Services.Greetd
import "Common"

ShellRoot {
    id: shell
    readonly property bool test: Quickshell.env("MINIMO_GREETER_TEST") === "1"
    readonly property string session: Quickshell.env("MINIMO_SESSION") || "Hyprland"
    property string pending: ""
    Component.onCompleted: Theme.dark = Quickshell.env("MINIMO_DARK") === "1"

    FloatingWindow {
        id: win
        visible: true
        color: "transparent"
        title: "Minimo OS"
        Login {
            id: login
            anchors.fill: parent
            user: Quickshell.env("MINIMO_USER") || "usuario"
            onSubmit: pw => {
                login.busy = true; login.error = ""
                if (shell.test) { fake.restart(); return }
                shell.pending = pw
                Greetd.createSession(login.user)
            }
        }
    }
    Timer { id: fake; interval: 700; onTriggered: { login.busy = false; if (login.password === "minimo") Qt.quit(); else { login.error = "Contraseña incorrecta (prueba: minimo)"; login.shake() } } }

    Connections {
        target: Greetd
        enabled: !shell.test
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) { Greetd.respond(shell.pending); shell.pending = "" }
            else if (error) login.error = message
        }
        function onReadyToLaunch() { Greetd.launch(shell.session.split(" ")) }
        function onAuthFailure(message) {
            login.busy = false; login.error = "Contraseña incorrecta"; login.shake()
            Greetd.cancelSession()
        }
        function onError(error) { login.busy = false; login.error = error; Greetd.cancelSession() }
    }
}
