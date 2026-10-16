// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Abre el navegador / gestor de archivos predeterminados (scripts/open-default.sh).
// No bloquea: si falla, `error` lleva un mensaje corto que la isla muestra unos segundos.
Singleton {
    id: root
    property string error: ""
    property string pending: ""
    signal launched()
    readonly property string script: Qt.resolvedUrl("../scripts/open-default.sh").toString().replace("file://", "")

    function open(kind) {
        if (proc.running) return          // un lanzamiento a la vez
        error = ""; pending = kind
        proc.command = [root.script, kind]
        proc.running = true
    }
    Process {
        id: proc
        stderr: StdioCollector { id: err }
        onExited: code => {
            if (code === 0) root.launched()
            else { root.error = root.pending === "files" ? I18n.tr("No se pudo abrir el gestor de archivos.") : I18n.tr("No se pudo abrir el navegador."); clear.restart() }
            root.pending = ""
        }
    }
    Timer { id: clear; interval: 4000; onTriggered: root.error = "" }
}
