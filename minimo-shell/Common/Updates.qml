// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "updates.js" as U

// Actualizaciones: comprobación de solo lectura con scripts/updates.py (git ls-remote; con
// la comprobación manual, también checkupdates para el sistema). Nunca instala, reinicia ni
// cierra sesión. Una sola comprobación a la vez; las manuales, como mucho una por minuto;
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
        schedule()
    }
    Connections { target: DisplayState; function onLoadedChanged() { if (DisplayState.loaded) root.restore() } }
    Component.onCompleted: if (DisplayState.loaded) restore()

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
