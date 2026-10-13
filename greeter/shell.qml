// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
// Pantalla de inicio de Minimo OS para greetd (Quickshell ≥ 0.3). Se lanza dentro de `cage`:
//   cage -s -d -- qs -p /usr/share/minimo-os/greeter
// Variables: MINIMO_USER (usuario), MINIMO_SESSION (comando, por defecto start-hyprland),
//            MINIMO_DARK=1 (modo oscuro), MINIMO_GREETER_TEST=1 (login de mentira, clave "minimo").
import QtQuick
import Quickshell
import Quickshell.Services.Greetd
import "Common"

ShellRoot {
    id: shell
    readonly property bool test: Quickshell.env("MINIMO_GREETER_TEST") === "1"
    readonly property string session: Quickshell.env("MINIMO_SESSION") || "start-hyprland"
    // Respuesta pendiente: la clave escrita se usa para el primer pedido secreto de PAM.
    // Si PAM pide algo más (p. ej. un segundo factor), la píldora muestra ese pedido y lo
    // que se escriba después va directo como respuesta.
    property string pending: ""
    property bool awaiting: false        // greetd espera una respuesta del usuario
    Component.onCompleted: Theme.dark = Quickshell.env("MINIMO_DARK") === "1"

    function fail(msg) {
        login.busy = false; login.prompt = ""; login.secret = true
        shell.awaiting = false; shell.pending = ""
        login.error = msg; login.shake()
    }

    // En cage la ventana ocupa toda la pantalla (cage maximiza cualquier ventana normal;
    // no hace falta layer-shell, que cage no garantiza).
    FloatingWindow {
        id: win
        visible: true
        color: Theme.pick("#FFFFFF", "#0A0A0B")
        title: "Minimo OS"
        Login {
            id: login
            anchors.fill: parent
            user: Quickshell.env("MINIMO_USER") || "usuario"
            onSubmit: pw => {
                login.busy = true; login.error = ""
                if (shell.test) { fake.restart(); return }
                if (shell.awaiting) {                       // respuesta a un pedido extra de PAM
                    shell.awaiting = false; login.prompt = ""; login.secret = true
                    login.password = ""
                    Greetd.respond(pw); return
                }
                if (!Greetd.available) { shell.fail("greetd no está disponible"); return }
                shell.pending = pw
                if (Greetd.state !== GreetdState.Inactive) Greetd.cancelSession()
                Greetd.createSession(login.user)
            }
        }
    }
    Timer { id: fake; interval: 700; onTriggered: login.password === "minimo" ? Qt.quit() : shell.fail("Contraseña incorrecta (prueba: minimo)") }

    Connections {
        target: Greetd
        enabled: !shell.test
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                if (shell.pending !== "" && !echoResponse) {        // primer pedido secreto: la clave
                    Greetd.respond(shell.pending); shell.pending = ""
                } else {                                            // pedido extra: lo contesta el usuario
                    shell.awaiting = true; login.busy = false
                    login.password = ""; login.prompt = message; login.secret = !echoResponse
                    login.focusField()
                }
            } else if (error) login.error = message
            // los mensajes informativos de PAM no necesitan respuesta (Quickshell la envía solo)
        }
        function onReadyToLaunch() {
            shell.pending = ""
            Greetd.launch(shell.session.split(" ").filter(s => s.length),
                          ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=Hyprland", "XDG_CURRENT_DESKTOP=Hyprland"])
        }
        // Quickshell ya cancela la sesión en ambos casos: basta con permitir reintentar.
        function onAuthFailure(message) { shell.fail("Contraseña incorrecta") }
        // Tras un fallo, Quickshell cancela la sesión y greetd responde con un error de
        // "cancel" (verificado con greetd 0.10.3): se ignora si no hay un intento en curso.
        function onError(error) { if (login.busy || shell.awaiting) shell.fail(error || "Error de greetd"); else console.info("greetd:", error) }
    }
}
