// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
// Pantalla de inicio de Minimo OS para greetd (Quickshell ≥ 0.3). Se lanza dentro de `cage`:
//   cage -s -d -- qs -p /usr/share/minimo-os/greeter
// Variables: MINIMO_USER (usuario), MINIMO_SESSION (comando, por defecto minimo-session),
//            MINIMO_DARK=1 (modo oscuro), MINIMO_GREETER_TEST=1 (login de mentira, clave "minimo").
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import "Common"
import "Common/sessions.js" as Sessions

ShellRoot {
    id: shell
    readonly property bool test: Quickshell.env("MINIMO_GREETER_TEST") === "1"
    readonly property string session: Quickshell.env("MINIMO_SESSION") || "minimo-session"
    // Sesiones: Minimo (minimo-session) + las de /usr/share/wayland-sessions válidas.
    // Las de X (xsessions) no se listan: el greeter corre en cage (Wayland) y greetd no
    // arranca un servidor X por sí mismo.
    readonly property string sessionsDir: Quickshell.env("MINIMO_SESSIONS_DIR") || "/usr/share/wayland-sessions"
    readonly property string cacheDir: Quickshell.env("MINIMO_GREETER_CACHE") || "/var/cache/minimo-greeter"
    property var sessions: Sessions.parseAll("", shell.session.split(" ").filter(s => s.length))
    property string chosen: "minimo"
    property string remembered: ""
    readonly property var chosenSession: sessions.find(s => s.id === chosen) ?? sessions[0]
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
            sessions: shell.sessions
            session: shell.chosen
            onSessionPicked: id => { shell.chosen = id; shell.remember(id) }
            onOutroDone: shell.test ? Qt.quit() : shell.launchSession()
            onCancelled: if (shell.awaiting && !shell.test) { Greetd.cancelSession(); shell.awaiting = false; login.prompt = ""; login.secret = true }
            // logind permite apagar/reiniciar a la sesión activa del asiento (la del greeter)
            onPowerOff: if (!shell.test) { powerProc.command = ["systemctl", "poweroff"]; powerProc.running = true }
            onReboot: if (!shell.test) { powerProc.command = ["systemctl", "reboot"]; powerProc.running = true }
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
    Process { id: powerProc }

    // Lista de sesiones (una sola lectura al arrancar; sin sondeos).
    Process {
        running: true
        command: ["sh", "-c", 'for f in "$1"/*.desktop; do [ -f "$f" ] && printf "@@FILE %s\\n" "$f" && cat "$f" && echo; done; exit 0', "sessions", shell.sessionsDir]
        stdout: StdioCollector {
            onStreamFinished: {
                shell.sessions = Sessions.parseAll(text, shell.session.split(" ").filter(s => s.length))
                shell.chosen = Sessions.pick(shell.sessions, shell.remembered)
            }
        }
    }
    // Última sesión elegida: /var/cache/minimo-greeter/last-session (la carpeta la crea
    // install-greeter.sh con dueño greeter). Si no se puede leer/escribir, se usa Minimo.
    FileView {
        path: shell.cacheDir + "/last-session"
        printErrors: false
        onLoaded: { shell.remembered = text().trim(); shell.chosen = Sessions.pick(shell.sessions, shell.remembered) }
    }
    Process { id: rememberProc }
    function remember(id) {
        if (shell.test) return
        // Escritura atómica (temporal + mv); los errores se ignoran (sin permisos: no se recuerda).
        rememberProc.command = ["sh", "-c", 'printf "%s\\n" "$2" > "$1/last-session.tmp" && mv -f "$1/last-session.tmp" "$1/last-session"', "remember", shell.cacheDir, id]
        rememberProc.running = true
    }
    Timer { id: fake; interval: 900; onTriggered: login.password === "minimo" ? login.succeed() : shell.fail("Contraseña incorrecta (prueba: minimo)") }

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
        // Autenticado: primero la salida suave (guiño + fundido), después se lanza la sesión.
        function onReadyToLaunch() { shell.pending = ""; login.succeed() }
    }
    function launchSession() {
            const s = shell.chosenSession
            Greetd.launch(s.exec, Sessions.envFor(s))
    }
    Connections {
        target: Greetd
        enabled: !shell.test
        // Quickshell ya cancela la sesión en ambos casos: basta con permitir reintentar.
        function onAuthFailure(message) { shell.fail("Contraseña incorrecta") }
        // Tras un fallo, Quickshell cancela la sesión y greetd responde con un error de
        // "cancel" (verificado con greetd 0.10.3): se ignora si no hay un intento en curso.
        function onError(error) { if (login.busy || shell.awaiting) shell.fail(error || "Error de greetd"); else console.info("greetd:", error) }
    }
}
