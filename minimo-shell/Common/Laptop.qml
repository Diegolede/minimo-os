// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Funciones de laptop: batería (avisos al 20 % y 5 %, enchufar/desenchufar), teclas de
// brillo y tapa. Al iniciar hace UNA lectura; el vigilante por eventos (upower --monitor)
// solo corre si hay batería, así que en una PC de escritorio no cuesta nada.
// Simulador: scripts/fake-laptop.sh (archivo ~/.cache/minimo/fake-battery.json).
Singleton {
    id: root
    readonly property string script: Qt.resolvedUrl("../scripts/battery.py").toString().replace("file://", "")
    property var bat: null                 // { pct, status, mins, fake? } | null
    readonly property bool present: bat !== null
    readonly property bool simulated: !!(bat && bat.fake)
    readonly property bool discharging: present && bat.status === "Discharging"
    readonly property bool charging: present && bat.status === "Charging"
    readonly property bool low: discharging && bat.pct <= 20
    readonly property bool critical: discharging && bat.pct <= 5
    property bool backlight: false
    property string notice: ""             // aviso breve en la isla compacta
    property string noticeKind: ""         // "low" | "critical" | "charging" | "unplugged" | "info"
    property real chargedAt: 0             // para la animación de carga
    // Un aviso por ciclo de descarga: se rearman al enchufar.
    property bool warnedLow: false
    property bool warnedCritical: false

    property real level: -1                // OSD: nivel 0–1 (volumen/brillo) como barrita; -1 = sin barra
    function say(msg, kind, ms, lvl) {
        notice = msg; noticeKind = kind; level = lvl === undefined ? -1 : Math.max(0, Math.min(1, lvl))
        noticeTimer.interval = ms || 3500; noticeTimer.restart()
    }
    Timer { id: noticeTimer; onTriggered: { root.notice = ""; root.noticeKind = ""; root.level = -1 } }

    // OSD de volumen: el atajo ya cambió el volumen con wpctl (funciona aunque la shell no
    // corra); acá solo se lee el valor una vez y se muestra en la isla con una barrita.
    property string volTarget: "@DEFAULT_AUDIO_SINK@"
    function volume(which) { volTarget = which === "mic" ? "@DEFAULT_AUDIO_SOURCE@" : "@DEFAULT_AUDIO_SINK@"; volRead.running = false; volRead.running = true }
    Process {
        id: volRead
        command: ["wpctl", "get-volume", root.volTarget]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /Volume:\s*([\d.]+)/.exec(text)
                if (!m) return
                const v = parseFloat(m[1]), muted = text.indexOf("MUTED") >= 0, mic = root.volTarget.indexOf("SOURCE") >= 0
                if (mic) root.say(muted ? I18n.tr("Micrófono silenciado") : I18n.tr("Micrófono activo"), "info", 1400)
                else root.say(muted ? I18n.tr("Silenciado") : I18n.tr("Volumen %1%", Math.round(v * 100)), "info", 1400, muted ? undefined : v)
            }
        }
    }
    // Brillo real: brightnessctl -m → "dev,class,actual,pct%,max"
    Process {
        id: briRead
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /,(\d+)%,/.exec(text)
                if (m) root.say(I18n.tr("Brillo %1%", m[1]), "info", 1400, parseInt(m[1]) / 100)
            }
        }
    }

    function update(b) {
        const prev = bat
        bat = b
        if (!b) { watcher.running = false; return }
        if (b.status !== "Discharging") { warnedLow = false; warnedCritical = false }
        if (prev && prev.status === "Discharging" && (b.status === "Charging" || b.status === "Full")) {
            chargedAt = Date.now(); say(I18n.tr("Cargando · %1%", b.pct), "charging")
        } else if (prev && prev.status !== "Discharging" && b.status === "Discharging") {
            say(I18n.tr("Cargador desconectado · %1%", b.pct), "unplugged")
        }
        if (b.status === "Discharging") {
            if (b.pct <= 5 && !warnedCritical) { warnedCritical = true; warnedLow = true; say(I18n.tr("Batería crítica · %1% · enchufá el cargador", b.pct), "critical", 8000) }
            else if (b.pct <= 20 && !warnedLow) { warnedLow = true; say(I18n.tr("Batería baja · %1%", b.pct), "low", 6000) }
        }
        if (!watcher.running) watcher.running = true
    }

    function rescan() { watcher.running = false; once.running = true }
    Process {
        id: once
        command: [root.script, "once"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { const j = JSON.parse(text); root.backlight = j.backlight; root.update(j.battery) } catch (e) {} }
        }
    }
    Process {
        id: watcher
        command: [root.script, "watch"]
        stdout: SplitParser { onRead: line => { try { root.update(JSON.parse(line)) } catch (e) {} } }
    }

    // Brillo: con retroiluminación real usa brightnessctl; si no, el brillo por shader.
    function brightness(dir) {
        const up = dir === "up"
        if (backlight) {
            briSet.command = ["brightnessctl", "-q", "set", up ? "5%+" : "5%-"]
            briSet.running = true                 // al terminar lee el porcentaje real
        } else {
            DisplayState.set(DisplayState.saturation, DisplayState.brightness + (up ? 0.05 : -0.05))
            say(I18n.tr("Brillo %1%", Math.round(DisplayState.brightness * 100)), "info", 1400, DisplayState.brightness)
        }
    }
    Process { id: briSet; onExited: briRead.running = true }

    // Tapa. Con monitor externo: apaga la pantalla interna. Sin él: bloquea con hyprlock
    // si está instalado (la suspensión la maneja systemd como siempre). En simulación solo
    // muestra el aviso: nunca bloquea ni suspende de verdad.
    readonly property var internal: Hyprland.monitors.values.filter(m => /^(eDP|LVDS|DSI)/.test(m.name))
    function lid(state) {
        const closed = state === "close"
        const external = Hyprland.monitors.values.some(m => !/^(eDP|LVDS|DSI)/.test(m.name))
        if (simulated || internal.length === 0) {
            say(closed ? (external ? I18n.tr("Tapa cerrada (simulación): se apagaría la pantalla interna")
                                   : I18n.tr("Tapa cerrada (simulación): se bloquearía la pantalla"))
                       : I18n.tr("Tapa abierta (simulación)"), "info", 4000)
            console.log("laptop: lid " + state + " (simulación, sin cambios)")
            return
        }
        if (closed && external)
            internal.forEach(m => Quickshell.execDetached(["hyprctl", "eval", 'hl.monitor({ output = "' + m.name + '", disabled = true })']))
        else if (closed)
            Quickshell.execDetached(["sh", "-c", "command -v hyprlock >/dev/null && (pidof hyprlock || hyprlock) >/dev/null 2>&1 &"])
        else
            Quickshell.execDetached(["hyprctl", "reload"])   // reactiva la pantalla interna
    }

    IpcHandler {
        target: "laptop"
        function rescan(): void { root.rescan() }
        function brightness(dir: string): void { root.brightness(dir) }
        function lid(state: string): void { root.lid(state) }
        function volume(which: string): void { root.volume(which) }
        function state(): string { return JSON.stringify({ battery: root.bat, backlight: root.backlight, notice: root.notice }) }
    }
}
