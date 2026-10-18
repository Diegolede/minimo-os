// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "petalerts.js" as Alerts

// Mini mascota: tres medidores que se calculan a partir de marcas de tiempo (sin
// tick de fondo). Solo mientras el panel está abierto se recalcula una vez por minuto.
//   · Comida: baja en 8 h desde la última vez que comió.
//   · Ánimo: baja en 5 h desde el último juego.
//   · Energía: baja en 2 h de uso continuo de la PC y se recarga con una pausa real
//     (inactividad de teclado y mouse, la misma que lo hace dormir).
// Avisos (Common/petalerts.js): al ENTRAR en necesidad (mismos umbrales que el ánimo) se
// manda un aviso por la isla (Notifs.post). Sin sondeo: un único Timer de un disparo apunta
// al próximo cruce de umbral. Con la mascota apagada (Ajustes) no hay timers ni avisos; los
// datos se conservan.
Singleton {
    id: root
    readonly property real foodSpan: 8 * 3600000
    readonly property real funSpan: 5 * 3600000
    readonly property real energySpan: 2 * 3600000
    // Umbrales de necesidad del modelo (los usan el ánimo, el panel y los avisos).
    readonly property var below: ({ food: 0.25, fun: 0.2, energy: 0.25 })
    readonly property real minPerNeed: 3 * 3600000     // mínimo entre avisos de la misma necesidad
    readonly property real minGlobal: 10 * 60000       // mínimo entre dos avisos cualesquiera
    readonly property bool enabled: DisplayState.petEnabled
    property var alerts: Alerts.initial()
    property bool loaded: false

    property real lastFed: Date.now()
    property real lastPlayed: Date.now()
    property real activeSince: Date.now()      // inicio del tramo actual sin pausas (no se guarda)
    property real now: Date.now()
    property int watchers: 0

    function clamp(v) { return Math.max(0, Math.min(1, v)) }
    readonly property real food: clamp(1 - (now - lastFed) / foodSpan)
    readonly property real fun: clamp(1 - (now - lastPlayed) / funSpan)
    readonly property real energy: IdleState.idle ? 1 : clamp(1 - (now - activeSince) / energySpan)
    readonly property int activeMinutes: Math.max(0, Math.round((now - activeSince) / 60000))

    // "tired" | "worried" | "" (para el ánimo del personaje)
    readonly property string mood: energy < below.energy ? "tired" : (food < below.food || fun < below.fun) ? "worried" : ""

    function acquire() { watchers++; now = Date.now() }
    function release() { watchers = Math.max(0, watchers - 1) }
    function feed() { lastFed = Date.now(); now = lastFed; evaluate(); save() }
    function play() { lastPlayed = Date.now(); now = lastPlayed; evaluate(); save() }

    // ---------- avisos ----------
    function levelsAt(t) {
        return { food: clamp(1 - (t - lastFed) / foodSpan), fun: clamp(1 - (t - lastPlayed) / funSpan),
                 energy: IdleState.idle ? 1 : clamp(1 - (t - activeSince) / energySpan) }
    }
    function textsFor(id) {
        if (id === "food") return [I18n.tr("Minimo tiene hambre"), I18n.tr("Abrí la isla y dale de comer.")]
        if (id === "fun") return [I18n.tr("Minimo se aburre"), I18n.tr("¿Jugamos un rato?")]
        return [I18n.tr("Minimo tiene sueño"), I18n.tr("Llevás mucho tiempo sin pausa. ¿Un descanso?")]
    }
    function evaluate() {
        if (!enabled || !loaded || !DisplayState.loaded) { alertTimer.stop(); return }
        const t = Date.now()
        const r = Alerts.step(alerts, levelsAt(t), below, t, minPerNeed, minGlobal)
        r.ended.forEach(id => Notifs.withdraw("pet-" + id))          // atendida: fuera el aviso viejo
        const changed = r.post !== "" || r.ended.length > 0
        alerts = r.alerts
        if (r.post !== "") {
            const tx = textsFor(r.post)
            Notifs.post({ tag: "pet-" + r.post, summary: tx[0], body: tx[1], action: "pet" })
        }
        if (changed) save()
        const m = { lastFed: lastFed, lastPlayed: lastPlayed, activeSince: activeSince, idle: IdleState.idle,
                    foodSpan: foodSpan, funSpan: funSpan, energySpan: energySpan }
        const next = Math.min(Alerts.nextCrossing(m, below, t), r.retryAt)
        if (next === Infinity) { alertTimer.stop(); return }
        alertTimer.interval = Math.max(1000, Math.min(next - t + 500, 6 * 3600000))
        alertTimer.restart()
    }
    Timer { id: alertTimer; repeat: false; onTriggered: root.evaluate() }
    Connections { target: DisplayState; function onLoadedChanged() { root.evaluate() } }
    onEnabledChanged: {
        if (enabled) {
            // Volver a encender: lo que ya está en necesidad cuenta como avisado (sin ráfaga).
            alerts = Alerts.suppress(alerts, levelsAt(Date.now()), below, Date.now())
            save(); evaluate()
        } else {
            alertTimer.stop()
            for (const id of ["food", "fun", "energy"]) Notifs.withdraw("pet-" + id)
        }
    }

    Timer { interval: 60000; repeat: true; running: root.watchers > 0; onTriggered: root.now = Date.now() }
    Connections {
        target: IdleState
        function onIdleChanged() { if (!IdleState.idle) { root.activeSince = Date.now(); root.now = root.activeSince } root.evaluate() }
    }

    function save() { if (loaded) file.setText(JSON.stringify({ lastFed: root.lastFed, lastPlayed: root.lastPlayed, alerts: root.alerts })) }
    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/minimo-os/pet.json"
        blockLoading: false
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text())
                if (s.lastFed > 0) root.lastFed = Math.min(s.lastFed, Date.now())
                if (s.lastPlayed > 0) root.lastPlayed = Math.min(s.lastPlayed, Date.now())
                root.alerts = Alerts.sane(s.alerts)
            } catch (e) {}
            root.loaded = true
            root.evaluate()
        }
        onLoadFailed: { root.loaded = true; root.evaluate() }
    }
}
