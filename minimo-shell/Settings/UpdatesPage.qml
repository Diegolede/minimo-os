// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../Common"
import "../Common/updates.js" as U

// Actualizaciones: versión instalada, estado de Minimo (clon git) y del sistema (pacman),
// y notas de versión (CHANGELOG.md / CHANGELOG.en.md). Si hay una versión nueva se muestran
// sus novedades (CHANGELOG remoto) y el botón "Actualizar" (git pull --ff-only + install.sh
// --update en segundo plano, con progreso); al terminar, "Reiniciar interfaz".
Column {
    id: root
    spacing: 18
    property bool shown: false
    readonly property string version: Updates.installed       // VERSION (se vigila al actualizar)
    property string notesText: ""
    property bool copiedCmd: false
    readonly property var notes: U.parseChangelog(notesText)
    readonly property var m: Updates.minimo || ({})
    property string remoteText: ""
    readonly property var remoteNotes: Updates.state === "available" ? U.newerNotes(remoteText, root.version) : []
    readonly property string remotePath: I18n.lang === "en" && m.notesEn ? m.notesEn : (m.notes || "")
    FileView { path: root.remotePath; blockLoading: false; printErrors: false; onLoaded: root.remoteText = text() }
    readonly property bool updating: Updates.phase === "running"
    function errorText(r) {
        switch (r) {
        case "dirty": return I18n.tr("Hay cambios locales en el repositorio que impiden actualizar. No se tocó nada.")
        case "offline": return I18n.tr("No se pudo descargar la versión nueva. Revisá la conexión y probá de nuevo.")
        case "pull": return I18n.tr("La copia local se separó de la publicada (git pull --ff-only no pudo avanzar). No se tocó nada.")
        case "pkexec": return I18n.tr("No se instalaron los paquetes nuevos (autorización cancelada).")
        case "repo": return I18n.tr("Esta instalación no es un clon git del repositorio.")
        default: return I18n.tr("El instalador terminó con errores. La versión nueva ya está descargada; revisá el registro.")
        }
    }

    // Notas y versión: se leen al mostrar la página (y al cambiar de idioma).
    readonly property string notesPath: shown || notesText ? Qt.resolvedUrl(I18n.lang === "en" ? "../CHANGELOG.en.md" : "../CHANGELOG.md").toString().replace("file://", "") : ""
    FileView { path: root.notesPath; blockLoading: false; printErrors: false; onLoaded: root.notesText = text() }

    Timer { id: copiedTimer; interval: 1800; onTriggered: root.copiedCmd = false }

    function when(t) { return t ? Qt.formatDateTime(new Date(t), "dd/MM/yyyy HH:mm") : I18n.tr("nunca") }
    function minimoText() {
        switch (Updates.state) {
        case "checking": return I18n.tr("Comprobando…")
        case "uptodate": return Updates.phase === "done" ? I18n.tr("Actualizado a %1", root.version) : I18n.tr("Actualizado")
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
    readonly property bool canCheck: !root.updating && !Updates.running && Updates.state !== "checking" && U.canCheck(clock.date.getTime(), Updates.lastCheck, false, true)
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

    // Versión nueva: novedades y botón "Actualizar".
    Card {
        visible: Updates.state === "available" && Updates.phase === "idle"
        Text { width: parent.width; wrapMode: Text.WordWrap; text: root.m.remoteVersion ? I18n.tr("Novedades de %1", root.m.remoteVersion) : I18n.tr("Novedades de la versión nueva"); color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold }
        Repeater {
            model: root.remoteNotes
            delegate: Column {
                id: rv
                required property var modelData
                width: parent.width; spacing: 4
                Text { visible: root.remoteNotes.length > 1; width: parent.width; text: I18n.tr("Versión %1", rv.modelData.version); color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold; topPadding: 6 }
                Repeater {
                    model: rv.modelData.sections
                    delegate: Column {
                        id: rs
                        required property var modelData
                        width: rv.width; spacing: 3; topPadding: 6
                        Text { width: parent.width; text: rs.modelData.title; color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                        Repeater {
                            model: rs.modelData.items
                            delegate: Text { required property string modelData; width: rs.width; wrapMode: Text.WordWrap; leftPadding: 12; text: "•  " + modelData; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13 }
                        }
                    }
                }
            }
        }
        Line { visible: root.remoteNotes.length === 0; text: I18n.tr("Las novedades no están disponibles todavía.") }
        Item { width: 1; height: 6 }
        Line { visible: !!root.m.dirty; text: I18n.tr("Hay cambios locales en el repositorio: «git pull --ff-only» no los pisa y se detiene si no puede avanzar.") }
        Line { text: I18n.tr("Se descarga la versión nueva y se vuelve a enlazar la configuración. No se cierra la sesión.") }
        Item { width: 1; height: 4 }
        Row {
            spacing: 10
            PillButton { icon: "update"; primary: true; text: I18n.tr("Actualizar"); onClicked: Updates.update() }
            PillButton {
                icon: "clipboard"
                text: root.copiedCmd ? I18n.tr("Copiado") : I18n.tr("Copiar comando")
                onClicked: { Clipboard.copyText(root.m.pull); root.copiedCmd = true; copiedTimer.restart() }
            }
        }
    }

    // Actualización en curso / resultado.
    Card {
        visible: Updates.phase !== "idle"
        Text {
            width: parent.width; wrapMode: Text.WordWrap
            text: Updates.phase === "running" ? I18n.tr("Actualizando…")
                : Updates.phase === "done" ? I18n.tr("Actualización lista")
                : Updates.phase === "needsudo" ? I18n.tr("Faltan paquetes nuevos")
                : I18n.tr("No se pudo actualizar")
            color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold
        }
        Rectangle {
            visible: Updates.phase === "running" || Updates.phase === "done"
            width: parent.width; height: 6; radius: 3; color: Theme.field
            Rectangle { width: parent.width * Updates.progress; height: parent.height; radius: 3; color: Theme.textPrimary; Behavior on width { NumberAnimation { duration: 250 } } }
        }
        Line { visible: Updates.phase === "running" && Updates.stepTitle !== ""; color: Theme.textPrimary; text: I18n.tr("Paso %1 de %2: %3", Updates.step + 1, Updates.total + 1, I18n.tr(Updates.stepTitle)) }
        Repeater {
            model: Updates.phase === "running" || Updates.phase === "done" ? Updates.steps : []
            delegate: Row {
                required property string modelData
                spacing: 6
                Icon { name: "check"; size: 14; tone: "gray"; anchors.verticalCenter: parent.verticalCenter }
                Text { text: I18n.tr(parent.modelData); color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12 }
            }
        }
        Line { visible: Updates.phase === "done"; text: I18n.tr("Para ver los cambios, reiniciá la interfaz. Las ventanas abiertas no se cierran.") }
        Line { visible: Updates.phase === "error"; color: Theme.textPrimary; text: root.errorText(Updates.errorReason) }
        Line { visible: Updates.phase === "needsudo"; text: I18n.tr("Esta versión necesita instalar: %1. El sistema te va a pedir la contraseña en su propia ventana; Minimo no la ve ni la guarda.", Updates.sudoPackages.join(", ")) }
        Item { width: 1; height: 4 }
        Row {
            spacing: 10
            PillButton { visible: Updates.phase === "done"; icon: "restart"; primary: true; text: I18n.tr("Reiniciar interfaz"); onClicked: Updates.restartShell() }
            PillButton { visible: Updates.phase === "needsudo"; primary: true; text: I18n.tr("Instalar paquetes"); onClicked: Updates.installPackages() }
            PillButton { visible: Updates.phase === "needsudo"; icon: "terminal"; text: I18n.tr("Abrir en terminal"); onClicked: Updates.openTerminal() }
            PillButton { visible: Updates.phase === "error"; primary: true; text: I18n.tr("Reintentar"); onClicked: Updates.update() }
            PillButton { visible: Updates.phase === "error" || Updates.phase === "done" || Updates.phase === "needsudo"; text: I18n.tr("Ver registro"); onClicked: Updates.showLog() }
            PillButton { visible: Updates.phase === "error"; text: I18n.tr("Cerrar"); onClicked: Updates.dismiss() }
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
