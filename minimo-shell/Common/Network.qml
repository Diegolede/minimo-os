// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Estado de red vía NetworkManager (nmcli). Solo consulta mientras alguien lo usa
// (acquire/release, p. ej. el menú de la isla abierto): cada 5 s, sin procesos fijos.
// La sección Wi-Fi se muestra solo si hay placa Wi-Fi y NO hay Ethernet conectada.
Singleton {
    id: root
    property int users: 0
    function acquire() { users++; if (users === 1) refresh() }
    function release() { users = Math.max(0, users - 1) }

    property bool hasNmcli: true
    property bool hasWifi: false          // existe un dispositivo Wi-Fi
    property bool wired: false            // hay una conexión Ethernet activa
    property bool wifiEnabled: false
    property string ssid: ""              // red actual ("" = sin conexión)
    property int signal: 0                // 0..100
    property var networks: []             // [{ ssid, signal, secure, active, known }]
    property var known: []                // nombres de conexiones Wi-Fi guardadas
    readonly property bool showWifi: hasNmcli && hasWifi && !wired

    property string connecting: ""        // SSID en curso
    property string error: ""             // último error (texto corto)

    // nmcli -t separa con ":" y escapa ":" dentro de los valores como "\:".
    function fields(line) {
        const out = []; let cur = ""
        for (let i = 0; i < line.length; i++) {
            const ch = line[i]
            if (ch === "\\" && i + 1 < line.length) { cur += line[++i]; continue }
            if (ch === ":") { out.push(cur); cur = ""; continue }
            cur += ch
        }
        out.push(cur); return out
    }

    function refresh() { if (!devs.running) devs.running = true }
    function scan() { if (!list.running) { list.rescan = true; list.running = true } }

    Timer { running: root.users > 0; interval: 5000; repeat: true; onTriggered: root.refresh() }

    // 1) Dispositivos: ¿Wi-Fi? ¿Ethernet conectada? + radio.
    Process {
        id: devs
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE dev && echo RADIO:$(nmcli radio wifi) && nmcli -t -f NAME,TYPE con show | grep ':802-11-wireless$' | sed 's/^/KNOWN:/'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let wifi = false, wired = false, en = false, known = []
                for (const l of text.split("\n")) {
                    if (l.startsWith("RADIO:")) { en = l.slice(6).trim() === "enabled"; continue }
                    if (l.startsWith("KNOWN:")) { known.push(root.fields(l.slice(6))[0]); continue }
                    const f = root.fields(l)
                    if (f[0] === "wifi") wifi = true
                    if (f[0] === "ethernet" && f[1] === "connected") wired = true
                }
                root.hasWifi = wifi; root.wired = wired; root.wifiEnabled = en; root.known = known
                if (root.showWifi) { list.rescan = false; list.running = true }
            }
        }
        onExited: code => { if (code === 127) root.hasNmcli = false }
    }

    // 2) Redes cercanas (cache de NM; `scan()` fuerza un rescan).
    Process {
        id: list
        property bool rescan: false
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", rescan ? "yes" : "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                const best = {}
                let cur = "", sig = 0
                for (const l of text.split("\n")) {
                    if (!l) continue
                    const f = root.fields(l)
                    const name = f[1]; if (!name) continue
                    const n = { ssid: name, signal: parseInt(f[2]) || 0, secure: !!f[3] && f[3] !== "--",
                                active: f[0] === "*", known: root.known.indexOf(name) >= 0 }
                    if (n.active) { cur = name; sig = n.signal }
                    if (!best[name] || best[name].signal < n.signal || n.active) best[name] = n
                }
                root.ssid = cur; root.signal = sig
                root.networks = Object.values(best).sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
            }
        }
    }

    function setEnabled(on) {
        Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"])
        wifiEnabled = on
        later.restart()
    }
    Timer { id: later; interval: 1500; onTriggered: root.refresh() }

    // Conectar: guardada → `con up`; abierta → directo; con clave → `dev wifi connect … password`.
    function connect(ssid, password) {
        error = ""; connecting = ssid
        const isKnown = known.indexOf(ssid) >= 0
        if (isKnown && !password) conn.command = ["nmcli", "con", "up", "id", ssid]
        else if (password) conn.command = ["nmcli", "dev", "wifi", "connect", ssid, "password", password]
        else conn.command = ["nmcli", "dev", "wifi", "connect", ssid]
        conn.running = true
    }
    function disconnect() {
        Quickshell.execDetached(["sh", "-c", "nmcli -t -f DEVICE,TYPE dev | grep ':wifi$' | cut -d: -f1 | xargs -r -n1 nmcli dev disconnect"])
        later.restart()
    }
    Process {
        id: conn
        stderr: StdioCollector { id: connErr }
        onExited: code => {
            if (code !== 0) {
                const t = connErr.text.toLowerCase()
                root.error = (t.includes("secrets") || t.includes("password") || t.includes("802-11-wireless-security"))
                    ? I18n.tr("Contraseña incorrecta") : I18n.tr("No se pudo conectar")
            }
            root.connecting = ""
            root.refresh()
        }
    }
}
