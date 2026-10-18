// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Estado del sistema para el panel de la isla (deslizar sobre la isla compacta).
// - Siempre: conectividad por eventos (`nmcli monitor`, sin sondeo) → `online` (punto rojo).
//   Ante cada cambio se lee el último estado que conoce NetworkManager (`nmcli networking
//   connectivity`, sin forzar una comprobación HTTP); solo al arrancar y al abrir el panel se
//   fuerza una (`... check`). Antes: `check` cada 10 s = un proceso y una petición HTTP cada 10 s.
// - Solo con el panel abierto (acquire/release): recursos cada 2 s y red/dispositivos cada 8 s,
//   con scripts/sysstatus.py (un proceso corto por consulta, nada fijo).
// No lee otros singletons.
Singleton {
    id: root
    property int users: 0
    function acquire() { users++; if (users === 1) { full.go(); conn.go() } }
    function release() { users = Math.max(0, users - 1) }

    // Conectividad: "full" | "limited" | "portal" | "none" | "unknown"
    property string connectivity: "unknown"
    readonly property bool known: connectivity !== "unknown" && connectivity !== ""
    readonly property bool online: connectivity === "full"

    property var res: null      // { cpu, memUsed, memTotal, diskUsed, diskTotal, temp }
    property var net: null      // { type, name, device, signal, connectivity }
    property var dev: null      // { keyboards, mice, audio, bluetooth, usb }
    property var gpu: null      // { name, util, temp } | null

    readonly property string script: Qt.resolvedUrl("../scripts/sysstatus.py").toString().replace("file://", "")

    function gib(b) { return (b / 1073741824).toFixed(1).replace(".", ",") }

    Process {
        id: conn
        property bool force: true
        function go() { force = true; if (!running) running = true }          // comprobación real (arranque, panel)
        function peek() { if (!running) { force = false; running = true } }   // último estado conocido (eventos)
        command: force ? ["nmcli", "networking", "connectivity", "check"] : ["nmcli", "networking", "connectivity"]
        stdout: StdioCollector { onStreamFinished: root.connectivity = text.trim() || "unknown" }
    }
    Component.onCompleted: conn.go()
    // Eventos de NetworkManager: conexión, estado y conectividad. Un proceso dormido, sin sondeo.
    Process {
        id: monitor
        running: true
        command: ["nmcli", "monitor"]
        // Cualquier línea es un cambio (conectividad, estado, dispositivos): se agrupan y se lee una vez.
        stdout: SplitParser { onRead: line => settle.restart() }
        // Si NetworkManager se reinicia (o falta nmcli), se reintenta en 30 s, sin bucles rápidos.
        onExited: retry.restart()
    }
    Timer { id: settle; interval: 600; onTriggered: conn.peek() }        // una lectura por ráfaga de eventos
    Timer { id: retry; interval: 30000; onTriggered: { monitor.running = true; conn.peek() } }

    Process {
        id: resP
        function go() { if (!running) running = true }
        command: [root.script, "res"]
        stdout: StdioCollector { onStreamFinished: { try { root.res = JSON.parse(text).res } catch (e) {} } }
    }
    Process {
        id: full
        function go() { if (!running) running = true }
        command: [root.script, "full"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    root.res = j.res; root.net = j.net; root.dev = j.dev; root.gpu = j.gpu
                    if (j.net && j.net.connectivity) root.connectivity = j.net.connectivity
                } catch (e) {}
            }
        }
    }
    Timer { running: root.users > 0; repeat: true; interval: 2000; onTriggered: resP.go() }
    Timer { running: root.users > 0; repeat: true; interval: 8000; onTriggered: full.go() }
}
