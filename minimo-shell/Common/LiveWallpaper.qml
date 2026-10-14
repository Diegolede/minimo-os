// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Fondo animado con mpvpaper (opcional, AUR): un solo proceso para todos los monitores,
// decodificación por hardware, sin audio. Para gastar lo mínimo se pausa (IPC de mpv):
//   · cuando todos los monitores muestran un escritorio con ventanas (si la opción está activa),
//   · cuando nadie usa la PC (inactividad).
// Las ventanas se re-evalúan solo con eventos de Hyprland (sin sondeo) y solo con el fondo activo.
Singleton {
    id: root
    property bool available: false
    readonly property bool active: available && DisplayState.liveWallpaper !== ""
    readonly property bool running: player.running
    readonly property string sock: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/minimo-wallpaper.sock"
    property bool covered: false
    readonly property bool paused: (DisplayState.livePauseCovered && covered) || IdleState.idle
    readonly property var extensions: ["mp4", "webm", "mkv", "mov", "gif"]

    Process { running: true; command: ["sh", "-c", "command -v mpvpaper >/dev/null"]; onExited: code => root.available = code === 0 }

    Process {
        id: player
        running: root.active
        command: ["mpvpaper", "-o", "no-audio loop-file=inf hwdec=auto panscan=1.0 input-ipc-server=" + root.sock,
                  "*", DisplayState.liveWallpaper]
        onRunningChanged: if (running) sendLater.restart()
    }
    // Cambio de archivo con el reproductor andando: reiniciarlo con el nuevo.
    Connections {
        target: DisplayState
        function onLiveWallpaperChanged() { if (player.running) { player.running = false; Qt.callLater(() => player.running = root.active) } }
    }

    onPausedChanged: send()
    // El socket aparece un instante después de arrancar mpv.
    Timer { id: sendLater; interval: 800; onTriggered: root.send() }
    function send() {
        if (!player.running) return
        Quickshell.execDetached(["python3", "-c",
            "import socket,sys\ns=socket.socket(socket.AF_UNIX)\ntry:\n s.connect(sys.argv[1]); s.send(sys.argv[2].encode()+b'\\n')\nexcept OSError: pass",
            root.sock, JSON.stringify({ command: ["set_property", "pause", root.paused] })])
    }

    function evaluate() {
        const mons = Hyprland.monitors.values
        root.covered = mons.length > 0 && mons.every(m => m.activeWorkspace && m.activeWorkspace.toplevels.values.length > 0)
    }
    Connections {
        target: Hyprland
        enabled: root.active && DisplayState.livePauseCovered
        function onRawEvent(ev) {
            const n = ev.name
            if (n === "openwindow" || n === "closewindow" || n === "movewindowv2" || n === "workspacev2" || n === "focusedmonv2") refresh.restart()
        }
    }
    // Una sola actualización por ráfaga de eventos.
    Timer { id: refresh; interval: 250; onTriggered: { Hyprland.refreshToplevels(); Qt.callLater(root.evaluate) } }
    onActiveChanged: if (active) refresh.restart()

    function isAnimated(path) {
        const m = path.toLowerCase().match(/\.([a-z0-9]+)$/)
        return !!m && extensions.indexOf(m[1]) >= 0
    }
}
