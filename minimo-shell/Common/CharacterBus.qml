// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Canal para disparar reacciones del personaje y mostrar la isla desde afuera:
//   qs -p ~/Proyectos/minimo-os/minimo-shell ipc call character react giggle
//   qs -p ~/Proyectos/minimo-os/minimo-shell ipc call character list | look 0.9 0 | sleep | wake
//   qs -p ~/Proyectos/minimo-os/minimo-shell ipc call island reveal|dismiss|open|close
Singleton {
    id: root
    signal react(string name)
    signal islandCommand(string cmd)
    signal gaze(real x, real y, int ms)
    signal pet()
    // Escritura en campos de texto del shell (el personaje entrecierra los ojos para leer).
    signal typed()
    signal typingStopped()
    signal squintFor(int ms)        // depuración: qs ipc call character squint 2000
    property int hearts: 0          // corazones vivos (tope de partículas)
    readonly property var names: ["hop", "doubleHop", "giggle", "lookAround", "surprise",
                                  "wink", "dizzy", "yawn", "curious", "greet", "happyBounce", "startled"]

    IpcHandler {
        target: "character"
        function react(name: string): string {
            if (root.names.indexOf(name) < 0) return "desconocida: " + name
            root.react(name); return "ok"
        }
        function list(): string { return root.names.join(" ") }
        // Forzar la mirada (x, y en -1..1) durante unos segundos.
        function look(x: real, y: real): void { root.gaze(x, y, 4000) }
        // Caricia (como varios clics seguidos sobre el personaje).
        function pet(): void { root.pet() }
        function squint(ms: int): void { root.squintFor(ms > 0 ? ms : 2000) }
        function sleep(): void { IdleState.sleepNow() }
        function wake(): void { IdleState.wake() }
    }
    IpcHandler {
        target: "island"
        function reveal(): void { root.islandCommand("show") }
        function dismiss(): void { root.islandCommand("hide") }
        function open(): void { root.islandCommand("open") }
        function close(): void { root.islandCommand("close") }
        function status(): void { root.islandCommand("status") }
        function apps(): void { root.islandCommand("apps") }
        function clipboard(): void { root.islandCommand("clipboard") }
        function pet(): void { root.islandCommand("pet") }
    }
}
