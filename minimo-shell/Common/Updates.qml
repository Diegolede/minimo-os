// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "updates.js" as U

// Actualizaciones: comprobación de solo lectura con scripts/updates.py (git ls-remote; con
// la comprobación manual, también checkupdates para el sistema). La comprobación nunca instala;
// solo el botón "Actualizar" (update()) ejecuta scripts/update-run.sh (git pull --ff-only +
// install.sh --update) y "Reiniciar interfaz" reinicia minimo-shell.service, sin cerrar sesión.
// Nunca se piden ni guardan contraseñas: si faltan paquetes, pkexec (diálogo de polkit) o una terminal. Una sola comprobación a la vez; las manuales, como mucho una por minuto;
// la automática (opcional) una por día con un único temporizador, sin sondeos.
Singleton {
    id: root
    property string state: "unknown"          // unknown | checking | uptodate | available | offline | error
    property var minimo: ({})                 // salida de updates.py (versión, rama, comando sugerido…)
    property string systemState: "unknown"    // idem para paquetes del sistema
    property int systemCount: 0
    property string systemReason: ""
    property real lastCheck: 0                // ms (Date.now)
    property real systemCheck: 0
    readonly property bool running: proc.running
    property bool withSystem: false
    readonly property string script: Qt.resolvedUrl("../scripts/updates.py").toString().replace("file://", "")
    readonly property string runScript: Qt.resolvedUrl("../scripts/update-run.sh").toString().replace("file://", "")
    readonly property string logPath: Quickshell.env("HOME") + "/.cache/minimo-update.log"

    // Versión instalada (se vigila: al actualizar cambia y la comprobación guardada deja de valer).
    property string installed: ""
    FileView {
        path: Qt.resolvedUrl("../VERSION").toString().replace("file://", "")
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { root.installed = text().trim(); root.reconcile() }
    }

    // Actualización en curso: idle | running | needsudo | error | done
    property string phase: "idle"
    property int step: 0
    property int total: 9
    property string stepTitle: ""
    property string errorReason: ""
    property var sudoPackages: []
    property var steps: []                    // títulos de pasos ya pasados
    property string newVersion: ""
    readonly property real progress: phase === "done" ? 1 : U.progress(step, total)

    // Restaura la última comprobación guardada (se muestra con su fecha; no se repite sola).
    function restore() {
        const l = DisplayState.updateLast || {}
        lastCheck = Number(l.t) || 0
        minimo = l.minimo || {}
        state = lastCheck ? U.sane(minimo.state) : "unknown"
        if (state === "checking") state = "unknown"
        systemCheck = Number(l.systemT) || 0
        systemState = l.system ? U.sane(l.system.state) : "unknown"
        if (systemState === "checking") systemState = "unknown"
        systemCount = l.system ? (Number(l.system.count) || 0) : 0
        systemReason = l.system ? (l.system.reason || "") : ""
        reconcile()
        schedule()
    }
    Connections { target: DisplayState; function onLoadedChanged() { if (DisplayState.loaded) root.restore() } }
    Component.onCompleted: if (DisplayState.loaded) restore()

    // Comprobación guardada con otra versión instalada (p. ej. ya se actualizó): se descarta,
    // así no queda "Actualización disponible" pegado.
    function reconcile() {
        if (!installed || !lastCheck || !U.stale(minimo, installed)) return
        minimo = ({}); state = "unknown"; lastCheck = 0
        DisplayState.setUpdateLast({ t: 0, minimo: {}, systemT: systemCheck,
                                     system: { state: systemState, count: systemCount, reason: systemReason } })
    }

    // Botón "Actualizar": descarga + instalador en modo actualización, en segundo plano.
    function update() {
        if (runner.running || phase === "running") return false
        phase = "running"; step = 0; total = 9; stepTitle = ""; errorReason = ""
        sudoPackages = []; steps = []; newVersion = ""
        const top = root.script.replace(/\/minimo-shell\/scripts\/updates\.py$/, "")
        runner.command = ["bash", root.runScript, top]
        runner.running = true
        return true
    }
    function onLine(line) {
        const p = U.parseLine(line)
        switch (p.kind) {
        case "step":
            if (stepTitle) steps = steps.concat([stepTitle])
            step = p.step; total = p.total || total; stepTitle = p.title; break
        case "needsSudo": sudoPackages = p.packages; break
        case "error": errorReason = p.reason; break
        case "version": newVersion = p.version; break
        case "finished": if (stepTitle) steps = steps.concat([stepTitle]); stepTitle = ""; break
        }
    }
    function runnerDone(code) {
        if (phase !== "running") return
        if (code === 0 && !errorReason) {
            phase = "done"
            if (newVersion) installed = newVersion
            minimo = ({}); state = "uptodate"; lastCheck = Date.now()
            DisplayState.setUpdateLast({ t: lastCheck, minimo: { state: "uptodate", version: installed }, systemT: systemCheck,
                                         system: { state: systemState, count: systemCount, reason: systemReason } })
        } else if (sudoPackages.length) phase = "needsudo"
        else { phase = "error"; if (!errorReason) errorReason = "install" }
    }
    // Paquetes nuevos: polkit pide la contraseña en su propio diálogo (no pasa por la shell).
    function installPackages() {
        if (!sudoPackages.length) return
        phase = "running"; stepTitle = ""
        pk.command = ["pkexec", "pacman", "-S", "--needed", "--noconfirm"].concat(sudoPackages)
        pk.running = true
    }
    // Alternativa: el instalador en una terminal (sudo lo pide ahí).
    function openTerminal() {
        const top = root.script.replace(/\/minimo-shell\/scripts\/updates\.py$/, "")
        Quickshell.execDetached(["ghostty", "-e", "bash", "-c",
            "\"$1\"/install.sh --update; echo; read -rp 'Enter para cerrar…' _", "minimo-update", top])
        phase = "idle"
    }
    function showLog() { Quickshell.execDetached(["xdg-open", root.logPath]) }
    function restartShell() { Quickshell.execDetached(["systemctl", "--user", "restart", "minimo-shell.service"]) }
    function dismiss() { if (phase !== "running") phase = "idle" }

    Process {
        id: runner
        stdout: SplitParser { onRead: data => root.onLine(data) }
        onExited: (code, status) => root.runnerDone(code)
    }
    Process {
        id: pk
        onExited: (code, status) => { if (code === 0) { root.phase = "idle"; root.update() } else { root.phase = "needsudo"; root.errorReason = "pkexec" } }
    }

    // manual: botón "Comprobar ahora" (incluye el sistema). Devuelve false si no se lanzó.
    function check(manual) {
        if (!U.canCheck(Date.now(), lastCheck, running, manual)) return false
        withSystem = manual
        state = "checking"
        if (manual) systemState = "checking"
        proc.command = ["python3", root.script].concat(manual ? ["--system"] : [])
        proc.running = true
        return true
    }

    function finish(text) {
        let d = null
        try { d = JSON.parse(text) } catch (e) { d = null }
        const now = Date.now()
        lastCheck = now
        if (d && d.minimo) { minimo = d.minimo; state = U.sane(d.minimo.state) }
        else { minimo = ({ state: "error", reason: "script" }); state = "error" }
        if (state === "checking") state = "error"
        if (withSystem) {
            systemCheck = now
            if (d && d.system) { systemState = U.sane(d.system.state); systemCount = Number(d.system.count) || 0; systemReason = d.system.reason || "" }
            else { systemState = "error"; systemCount = 0; systemReason = "script" }
            if (systemState === "checking") systemState = "error"
        }
        DisplayState.setUpdateLast({ t: lastCheck, minimo: minimo, systemT: systemCheck,
                                     system: { state: systemState, count: systemCount, reason: systemReason } })
        schedule()
    }

    Process {
        id: proc
        stdout: StdioCollector { onStreamFinished: if (root.state === "checking") root.finish(text) }
        // Si el proceso termina sin salida (p. ej. falta python3), no queda "Comprobando" para siempre.
        onRunningChanged: if (!running) settle.restart()
    }
    Timer { id: settle; interval: 1500; onTriggered: if (root.state === "checking" && !proc.running) root.finish("") }

    // Automática: un solo temporizador hasta la próxima vez (24 h desde la última).
    function schedule() {
        autoTimer.stop()
        if (!DisplayState.updateAutoCheck || !DisplayState.loaded) return
        autoTimer.interval = U.autoDelay(Date.now(), lastCheck)
        autoTimer.start()
    }
    Connections { target: DisplayState; function onUpdateAutoCheckChanged() { root.schedule() } }
    Timer { id: autoTimer; repeat: false; onTriggered: { if (!root.check(false)) root.schedule() } }
}
