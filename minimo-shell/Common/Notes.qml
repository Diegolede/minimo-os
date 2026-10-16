// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "notes.js" as N

// Notas de la isla, en ~/.config/minimo-os/notes.json. Escritura atómica (FileView escribe
// un temporal y lo renombra); al editar se guarda 500 ms después de la última tecla.
Singleton {
    id: root
    property var notes: []            // [{ id, text, updated }] (más reciente primero)
    property bool loaded: false
    readonly property string dir: Quickshell.env("HOME") + "/.config/minimo-os"

    function create() { const r = N.add(notes, Date.now()); notes = r.notes; return r.id }
    function get(id) { return notes.find(n => n.id === id) ?? null }
    function edit(id, text) { const next = N.update(notes, id, text, Date.now()); if (next !== notes) { notes = next; saveLater.restart() } }
    function remove(id) { notes = N.remove(notes, id); save() }
    // Al cerrar el editor: quita notas vacías y guarda ya.
    function flush() { notes = N.prune(notes); save() }
    function title(text) { return N.title(text) }
    function preview(text) { return N.preview(text) }

    function save() {
        saveLater.stop()
        if (!loaded) return              // nunca pisar el archivo antes de leerlo
        file.setText(N.serialize(N.prune(notes)))
    }
    Timer { id: saveLater; interval: 500; onTriggered: root.save() }

    Process {
        running: true
        command: ["mkdir", "-p", root.dir]
        onExited: file.path = root.dir + "/notes.json"
    }
    FileView {
        id: file
        blockLoading: false
        printErrors: false
        atomicWrites: true
        onLoaded: { root.notes = N.parse(text()); root.loaded = true }
        onLoadFailed: root.loaded = true   // aún no existe
    }
}
