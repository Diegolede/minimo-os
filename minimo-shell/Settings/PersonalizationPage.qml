// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../Common"

// Personalización: fondo de pantalla + opciones de la isla y del personaje.
Column {
    id: root
    spacing: 20
    signal pickerOpened()       // el selector de archivos necesita el teclado

    readonly property string mainDir: Quickshell.env("HOME") + "/Imágenes/Fondos"
    property var images: []

    function refresh() { scan.running = false; scan.running = true }
    Component.onCompleted: refresh()

    // Solo fondos reales: el actual, los elegidos antes y los que el usuario agregó a
    // ~/Imágenes/Fondos (sin los de ejemplo "minimo-*"). Se descartan archivos inexistentes.
    Process {
        id: scan
        property var found: []
        command: ["sh", "-c",
            'mkdir -p "$HOME/Imágenes/Fondos"; for f in "$@"; do [ -f "$f" ] && echo "$f" || echo "!$f"; done; ' +
            'for d in "$HOME/Imágenes/Fondos" "$HOME/Pictures/Wallpapers"; do [ -d "$d" ] && find "$d" -maxdepth 1 -type f ! -name "minimo-*" \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \\) | sort; done',
            "sh"].concat(DisplayState.wallpaper ? [DisplayState.wallpaper] : []).concat(DisplayState.wallpaperHistory)
        stdout: SplitParser { onRead: line => scan.found.push(line) }
        onStarted: found = []
        onExited: {
            const missing = found.filter(l => l.startsWith("!")).map(l => l.slice(1))
            const ok = found.filter(l => l !== "" && !l.startsWith("!"))
            root.images = ok.filter((p, i) => ok.indexOf(p) === i)
            if (missing.some(p => DisplayState.wallpaperHistory.indexOf(p) >= 0)) DisplayState.forgetWallpapers(missing)
        }
    }
    // Quitar un fondo: los de ~/Imágenes/Fondos van a la papelera (gio trash; si no está, se borran);
    // los de otras carpetas solo salen de la lista. Si era el actual, queda sin fondo.
    function remove(path, owned) {
        DisplayState.removeWallpaper(path)
        root.images = root.images.filter(p => p !== path)
        if (owned) { trash.command = ["sh", "-c", 'gio trash -- "$1" 2>/dev/null || rm -f -- "$1"', "sh", path]; trash.running = true }
    }
    Process { id: trash; onExited: root.refresh() }
    Process {
        id: picker
        command: ["zenity", "--file-selection", "--title=Elegir fondo de pantalla",
                  "--filename=" + root.mainDir + "/",
                  "--file-filter=Imágenes | *.png *.jpg *.jpeg *.webp"]
        stdout: SplitParser { onRead: line => { if (line.trim() !== "") DisplayState.setWallpaper(line.trim()) } }
        onExited: root.refresh()
    }

    SectionTitle { text: "Fondo de pantalla" }

    Grid {
        id: grid
        columns: 3
        spacing: 14
        width: parent.width
        readonly property real tileW: (width - spacing * (columns - 1)) / columns

        Repeater {
            model: root.images
            delegate: WallpaperTile {
                width: grid.tileW; height: Math.round(grid.tileW * 10 / 16)
                owned: path.startsWith(root.mainDir + "/")
                onPicked: DisplayState.setWallpaper(path)
                onRemoveRequested: root.remove(path, owned)
            }
        }
    }

    Row {
        spacing: 8
        PillButton { icon: "folder"; text: "Elegir imagen…"; onClicked: if (!picker.running) { root.pickerOpened(); picker.running = true } }
        PillButton { text: "Sin fondo"; outlined: true; onClicked: DisplayState.setWallpaper("") }
    }

    LiveWallpaperCard { width: parent.width; onPickerOpened: root.pickerOpened() }
    Text { text: "Carpeta: ~/Imágenes/Fondos"; color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 11 }

    SectionTitle { text: "Apariencia" }
    Rectangle {
        width: parent.width
        height: ap.implicitHeight
        radius: 20
        color: Theme.surface; border.width: 1; border.color: Theme.track
        Column {
            id: ap
            width: parent.width
            Item {
                width: parent.width; height: 56
                Text { anchors.left: parent.left; anchors.leftMargin: 18; anchors.verticalCenter: parent.verticalCenter; text: "Apariencia"; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 14 }
                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                    width: 184; height: 32; radius: 16; color: Theme.field
                    Row {
                        anchors.fill: parent; anchors.margins: 3
                        Repeater {
                            model: [{ id: "light", label: "Claro" }, { id: "dark", label: "Oscuro" }]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool cur: DisplayState.theme === modelData.id
                                width: parent.width / 2; height: parent.height; radius: height / 2
                                color: cur ? Theme.fill : (thm.containsMouse ? Theme.hover : "transparent")
                                Text { anchors.centerIn: parent; text: modelData.label; color: parent.cur ? Theme.onAccent : Theme.textPrimary; font.family: Theme.font; font.pixelSize: 12; font.weight: parent.cur ? Font.DemiBold : Font.Normal }
                                MouseArea { id: thm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: DisplayState.setTheme(modelData.id) }
                            }
                        }
                    }
                }
            }
        }
    }

    SectionTitle { text: "Isla dinámica" }
    Rectangle {
        width: parent.width
        height: opts.implicitHeight
        radius: 20
        color: Theme.surface; border.width: 1; border.color: Theme.track
        Column {
            id: opts
            width: parent.width
            SwitchRow {
                width: parent.width
                text: "Ocultar isla automáticamente"
                detail: "Se esconde arriba y aparece al pasar el mouse."
                checked: DisplayState.islandAutoHide
                onToggled: v => DisplayState.setIslandAutoHide(v)
            }
            Rectangle { x: 18; width: parent.width - 36; height: 1; color: Theme.track }
            SwitchRow {
                width: parent.width
                text: "Ocultamiento inteligente"
                detail: "Oculta la isla cuando hay una app abierta en el escritorio."
                checked: DisplayState.islandSmartHide
                onToggled: v => DisplayState.setIslandSmartHide(v)
            }
            Rectangle { x: 18; width: parent.width - 36; height: 1; color: Theme.track }
            SwitchRow {
                width: parent.width
                text: "Personaje animado"
                detail: "Sigue el mouse, parpadea, baila y se duerme."
                checked: DisplayState.characterAnimated
                onToggled: v => DisplayState.setCharacterAnimated(v)
            }
            Rectangle { x: 18; width: parent.width - 36; height: 1; color: Theme.track }
            // Dormir tras inactividad (segmentado 1/2/5 min).
            Item {
                width: parent.width; height: 64
                Column {
                    anchors.left: parent.left; anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text { text: "Dormir tras inactividad"; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 14 }
                    Text { text: "Sin teclado ni mouse en toda la PC."; color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12 }
                }
                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                    width: 168; height: 32; radius: 16; color: Theme.field
                    Row {
                        anchors.fill: parent; anchors.margins: 3
                        Repeater {
                            model: [1, 2, 5]
                            delegate: Rectangle {
                                required property int modelData
                                readonly property bool cur: DisplayState.sleepMinutes === modelData
                                width: parent.width / 3; height: parent.height; radius: height / 2
                                color: cur ? Theme.fill : (zm.containsMouse ? Theme.hover : "transparent")
                                Text { anchors.centerIn: parent; text: modelData + " min"; color: parent.cur ? Theme.onAccent : Theme.textPrimary; font.family: Theme.font; font.pixelSize: 12; font.weight: parent.cur ? Font.DemiBold : Font.Normal }
                                MouseArea { id: zm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: DisplayState.setSleepMinutes(modelData) }
                            }
                        }
                    }
                }
            }
        }
    }

    PinsEditor { width: parent.width }
}
