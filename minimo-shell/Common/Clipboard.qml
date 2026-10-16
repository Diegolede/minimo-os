// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Historial del portapapeles. Lo guarda cliphist, alimentado por `wl-paste --watch`
// (systemd/minimo-clipboard.service): sin sondeos. La lista se lee solo al abrir la vista.
// Los fijados se guardan aparte (~/.config/minimo-os/clip-pins.json), así sobreviven a
// "Borrar historial" y a reinicios. Solo se fija texto.
Singleton {
    id: root
    property var items: []          // [{ line, id, text, binary }] (más reciente primero)
    property var pins: []           // [string]
    property bool available: true   // false si falta cliphist
    readonly property int maxItems: 40
    readonly property string pinsFile: Quickshell.env("HOME") + "/.config/minimo-os/clip-pins.json"

    function refresh() { lister.running = false; lister.running = true }

    // Copiar: el elemento vuelve a ser lo último copiado (pegar con Ctrl+V).
    // Imágenes: se restauran con su tipo (image/png, image/jpeg…) leído de la vista previa de
    // cliphist ("[[ binary data 182 KiB png 1920x1080 ]]"); texto: wl-copy lo detecta solo.
    function mimeOf(item) {
        const m = item.binary ? item.text.match(/binary data .*?\b(png|jpe?g|webp|gif|bmp)\b/i) : null
        return m ? "image/" + m[1].toLowerCase().replace("jpg", "jpeg") : ""
    }
    function copy(item) {
        const mime = mimeOf(item)
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist decode | if [ -n "$2" ]; then wl-copy --type "$2"; else wl-copy; fi',
                                 "copy", item.line, mime])
    }
    function copyText(text) { Quickshell.execDetached(["wl-copy", "--", text]) }
    function remove(item) {
        items = items.filter(i => i.id !== item.id)
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist delete', "delete", item.line])
    }
    // Borra el historial; los fijados quedan.
    function clear() { items = []; Quickshell.execDetached(["cliphist", "wipe"]) }

    function isPinned(text) { return pins.indexOf(text) >= 0 }
    function unpin(text) { pins = pins.filter(p => p !== text); savePins() }
    // El texto de la lista puede venir recortado: se decodifica el original antes de fijarlo.
    function pin(item) {
        if (item.binary) return
        decoder.command = ["sh", "-c", 'printf "%s" "$1" | cliphist decode', "decode", item.line]
        decoder.running = true
    }
    function savePins() { pinsView.setText(JSON.stringify(pins)) }

    Process {
        id: lister
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t")
                    if (tab < 1) continue
                    const t = line.slice(tab + 1)
                    out.push({ line: line, id: line.slice(0, tab), text: t, binary: /^\[\[ binary data .*\]\]$/.test(t) })
                    if (out.length >= root.maxItems) break
                }
                root.items = out
            }
        }
        onExited: code => root.available = code === 0
    }
    Process {
        id: decoder
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text
                if (t.trim() === "" || root.isPinned(t)) return
                root.pins = [t].concat(root.pins).slice(0, 24)
                root.savePins()
            }
        }
    }
    FileView {
        id: pinsView
        path: root.pinsFile
        blockLoading: false
        printErrors: false
        onLoaded: { try { const p = JSON.parse(text()); if (Array.isArray(p)) root.pins = p.filter(x => typeof x === "string") } catch (e) {} }
    }
}
