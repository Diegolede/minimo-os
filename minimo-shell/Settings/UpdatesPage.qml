// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../Common"
import "../Common/updates.js" as U

// Actualizaciones: versión instalada, estado de Minimo (clon git) y del sistema (pacman),
// y notas de versión (CHANGELOG.md / CHANGELOG.en.md). Nada se instala desde aquí: si hay
// una versión nueva se muestra el comando para ejecutarlo en una terminal.
Column {
    id: root
    spacing: 18
    property bool shown: false
    property string version: ""
    property string notesText: ""
    property bool copiedCmd: false
    readonly property var notes: U.parseChangelog(notesText)
    readonly property var m: Updates.minimo || ({})

    // Notas y versión: se leen al mostrar la página (y al cambiar de idioma).
    readonly property string notesPath: shown || notesText ? Qt.resolvedUrl(I18n.lang === "en" ? "../CHANGELOG.en.md" : "../CHANGELOG.md").toString().replace("file://", "") : ""
    FileView { path: root.notesPath; blockLoading: false; printErrors: false; onLoaded: root.notesText = text() }
    FileView { path: Qt.resolvedUrl("../VERSION").toString().replace("file://", ""); onLoaded: root.version = text().trim() }
    Timer { id: copiedTimer; interval: 1800; onTriggered: root.copiedCmd = false }

    function when(t) { return t ? Qt.formatDateTime(new Date(t), "dd/MM/yyyy HH:mm") : I18n.tr("nunca") }
    function minimoText() {
        switch (Updates.state) {
        case "checking": return I18n.tr("Comprobando…")
        case "uptodate": return I18n.tr("Actualizado")
        case "available": return root.m.remoteVersion && root.m.remoteVersion !== root.version ? I18n.tr("Actualización disponible: %1", root.m.remoteVersion) : I18n.tr("Actualización disponible")
        case "offline": return I18n.tr("Sin conexión")
        case "error": return I18n.tr("Error al comprobar")
        default: return I18n.tr("Desconocido")
        }
    }
    function minimoDetail() {
        const r = root.m.reason || ""
        if (Updates.state === "unknown" && !Updates.lastCheck) return I18n.tr("Todavía no se comprobó.")
        if (r === "no-repo" || r === "no-git") return I18n.tr("Esta instalación no es un clon git del repositorio: no se puede comprobar.")
        if (r === "detached" || r === "no-upstream") return I18n.tr("El repositorio no sigue una rama remota: no se puede comprobar.")
        if (Updates.state === "offline") return I18n.tr("No se pudo consultar GitHub. Probá de nuevo con conexión.")
        if (Updates.state === "error") return I18n.tr("No se pudo comprobar. No se instaló nada.")
        if (Updates.state === "available") return I18n.tr("Hay cambios nuevos publicados en GitHub.")
        if (Updates.state === "uptodate" && root.m.ahead) return I18n.tr("Tenés cambios más nuevos que la versión publicada.")
        if (Updates.state === "uptodate") return I18n.tr("Tenés la última versión publicada.")
        return ""
    }
    function systemText() {
        switch (Updates.systemState) {
        case "checking": return I18n.tr("Comprobando…")
        case "uptodate": return I18n.tr("Sistema actualizado")
        case "available": return I18n.tr("%1 actualizaciones de paquetes", Updates.systemCount)
        case "offline": return I18n.tr("Sin conexión")
        case "error": return I18n.tr("Error al comprobar")
        default: return I18n.tr("Desconocido")
        }
    }
    function systemDetail() {
        if (Updates.systemReason === "no-checkupdates") return I18n.tr("Para comprobarlo hace falta checkupdates (paquete pacman-contrib).")
        if (Updates.systemState === "available") return I18n.tr("Se instalan con «sudo pacman -Syu» en una terminal.")
        if (Updates.systemState === "unknown") return I18n.tr("Se comprueba con «Comprobar ahora».")
        return ""
    }
    readonly property bool canCheck: !Updates.running && Updates.state !== "checking" && U.canCheck(clock.date.getTime(), Updates.lastCheck, false, true)
    SystemClock { id: clock; precision: SystemClock.Seconds; enabled: root.shown }

    component Card: Rectangle {
        default property alias content: inner.data
        width: root.width; height: inner.implicitHeight + 36; radius: 20
        color: Theme.surface
        Column { id: inner; x: 18; y: 18; width: parent.width - 36; spacing: 6 }
    }
    component Line: Text {
        width: parent ? parent.width : 0; wrapMode: Text.WordWrap
        color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12
    }

    // Minimo OS.
    Card {
        Item {
            width: parent.width; height: Math.max(head.implicitHeight, btn.height)
            Column {
                id: head
                anchors.left: parent.left; anchors.right: btn.left; anchors.rightMargin: 12
                spacing: 2
                Text { width: parent.width; wrapMode: Text.WordWrap; text: root.version ? I18n.tr("Minimo OS %1", root.version) : "Minimo OS"; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 18; font.weight: Font.DemiBold }
                Text { width: parent.width; wrapMode: Text.WordWrap; text: root.minimoText(); color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 14 }
            }
            PillButton {
                id: btn
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                primary: root.canCheck && Updates.state !== "available"
                icon: "update"
                text: Updates.running || Updates.state === "checking" ? I18n.tr("Comprobando…") : I18n.tr("Comprobar ahora")
                opacity: root.canCheck ? 1 : 0.5
                onClicked: if (root.canCheck) Updates.check(true)
            }
        }
        Line { text: root.minimoDetail(); visible: text !== "" }
        Line { text: I18n.tr("Última comprobación: %1", root.when(Updates.lastCheck)) }
    }

    // Versión nueva: solo el comando (no se descarga ni ejecuta nada desde aquí).
    Card {
        visible: Updates.state === "available" && (root.m.pull || "") !== ""
        Text { width: parent.width; wrapMode: Text.WordWrap; text: I18n.tr("Para actualizar, ejecutá en una terminal:"); color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 14 }
        Rectangle {
            width: parent.width; height: cmd.implicitHeight + 20; radius: 12; color: Theme.field
            Text { id: cmd; x: 12; y: 10; width: parent.width - 24; wrapMode: Text.WrapAnywhere; text: root.m.pull || ""; color: Theme.textPrimary; font.family: "monospace"; font.pixelSize: 12 }
        }
        Line { visible: !!root.m.dirty; text: I18n.tr("Hay cambios locales en el repositorio: «git pull --ff-only» no los pisa y se detiene si no puede avanzar.") }
        Line { text: I18n.tr("Nada se instala ni se reinicia solo. El instalador vuelve a enlazar todo y agrega los paquetes nuevos.") }
        Item { width: 1; height: 4 }
        PillButton {
            icon: "clipboard"
            primary: true
            text: root.copiedCmd ? I18n.tr("Copiado") : I18n.tr("Copiar comando")
            onClicked: { Clipboard.copyText(root.m.pull); root.copiedCmd = true; copiedTimer.restart() }
        }
    }

    SectionTitle { text: I18n.tr("Sistema (paquetes de Arch)") }
    Card {
        Text { width: parent.width; wrapMode: Text.WordWrap; text: root.systemText(); color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 14 }
        Line { text: root.systemDetail(); visible: text !== "" }
        Line { visible: Updates.systemCheck > 0; text: I18n.tr("Última comprobación: %1", root.when(Updates.systemCheck)) }
    }

    Rectangle {
        width: parent.width; height: auto.implicitHeight; radius: 20; color: Theme.surface
        SwitchRow {
            id: auto
            width: parent.width
            text: I18n.tr("Buscar versiones nuevas automáticamente")
            detail: I18n.tr("Una vez por día y sin instalar nada. Los paquetes del sistema solo se comprueban con «Comprobar ahora».")
            checked: DisplayState.updateAutoCheck
            onToggled: v => DisplayState.setUpdateAutoCheck(v)
        }
    }

    SectionTitle { text: I18n.tr("Novedades") }
    Repeater {
        model: root.notes
        delegate: Card {
            id: rel
            required property var modelData
            Text {
                width: parent.width; wrapMode: Text.WordWrap
                text: rel.modelData.next ? I18n.tr("Próxima versión (sin publicar)") : I18n.tr("Versión %1", rel.modelData.version) + (rel.modelData.date ? " · " + rel.modelData.date : "")
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold
            }
            Repeater {
                model: rel.modelData.sections
                delegate: Column {
                    id: sec
                    required property var modelData
                    width: parent.width; spacing: 4; topPadding: 8
                    Text { width: parent.width; text: sec.modelData.title; color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                    Repeater {
                        model: sec.modelData.items
                        delegate: Text {
                            required property string modelData
                            width: sec.width; wrapMode: Text.WordWrap; leftPadding: 12
                            text: "•  " + modelData
                            color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13; lineHeight: 1.15
                        }
                    }
                }
            }
        }
    }
    Line { visible: root.notes.length === 0 && root.notesText === ""; text: I18n.tr("Cargando…") }
}
