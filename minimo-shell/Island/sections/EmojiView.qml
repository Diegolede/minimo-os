// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../../Common"
import "../../Common/emoji.js" as E

// Selector de emojis dentro de la isla (acceso fijable "Emojis"). Categorías + búsqueda
// (español e inglés, sin tildes). Clic: copia la secuencia exacta con wl-copy y muestra
// "Copiado"; no escribe nada solo. Abrir la vista no toca el portapapeles.
// Los datos (assets/emoji/emoji.json) se leen la primera vez que se abre.
Item {
    id: root
    signal back()
    property bool active: false
    property string raw: ""
    property string cat: "caras"
    property string copied: ""
    implicitHeight: col.implicitHeight

    readonly property var cats: raw ? E.parse(raw, I18n.lang) : []
    readonly property var current: cats.find(c => c.id === cat) ?? (cats.length ? cats[0] : null)
    readonly property bool searching: field.text.trim() !== ""
    readonly property var shown: searching ? E.search(cats, field.text, 64) : (current ? current.items : [])
    readonly property int tone: DisplayState.emojiTone

    function reset() { field.text = ""; field.focus = false; copied = ""; flick.contentY = 0 }
    onActiveChanged: if (active && !raw) data.path = Qt.resolvedUrl("../../assets/emoji/emoji.json").toString().replace("file://", "")

    function pick(item) {
        const s = E.textFor(item, root.tone)
        Clipboard.copyText(s)
        root.copied = s
        copiedTimer.restart()
    }

    FileView {
        id: data
        blockLoading: false
        printErrors: false
        onLoaded: root.raw = text()
    }
    Timer { id: copiedTimer; interval: 1600; onTriggered: root.copied = "" }

    Column {
        id: col
        width: parent.width
        spacing: 12

        // Cabecera: volver · título · tono de piel (clic: siguiente tono).
        Item {
            width: parent.width; height: 32
            Rectangle {
                width: 32; height: 32; radius: 16
                color: bm.containsMouse ? Theme.hover : Theme.surface
                Icon { anchors.centerIn: parent; name: "back"; size: 18 }
                MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.back() }
            }
            Text {
                anchors.centerIn: parent
                text: I18n.tr("Emojis")
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold
            }
            Rectangle {
                anchors.right: parent.right
                width: 32; height: 32; radius: 16
                color: tm.containsMouse ? Theme.hover : Theme.surface
                Text { anchors.centerIn: parent; text: E.withTone("\u270B", root.tone); font.family: Theme.emojiFont; font.pixelSize: 17 }
                MouseArea {
                    id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: DisplayState.setEmojiTone((root.tone + 1) % E.TONES.length)
                }
                Accessible.name: I18n.tr("Tono de piel")
            }
        }

        // Búsqueda (sin bordes: píldora gris).
        Rectangle {
            width: parent.width; height: 38; radius: 19
            color: Theme.field
            MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onPressed: field.forceActiveFocus() }
            Icon { id: lupa; x: 14; anchors.verticalCenter: parent.verticalCenter; name: "search"; tone: "gray"; size: 16 }
            TextInput {
                id: field
                anchors.left: lupa.right; anchors.leftMargin: 8
                anchors.right: parent.right; anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.textPrimary
                selectionColor: Theme.hover; selectedTextColor: Theme.textPrimary
                cursorDelegate: Rectangle { width: 2; radius: 1; color: Theme.textPrimary; visible: field.activeFocus && field.cursorVisible }
                font.family: Theme.font; font.pixelSize: 14
                clip: true
                onTextChanged: flick.contentY = 0
                Keys.onReturnPressed: if (root.shown.length > 0) root.pick(root.shown[0])
                Keys.onEscapePressed: e => { if (field.text) field.text = ""; else e.accepted = false }
                Text {
                    visible: !field.text
                    text: I18n.tr("Buscar emoji")
                    color: Theme.textSecondary
                    font: field.font
                }
            }
        }

        // Categorías (solo sin búsqueda).
        Row {
            visible: !root.searching
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0
            Repeater {
                model: root.cats
                delegate: Rectangle {
                    id: tab
                    required property var modelData
                    readonly property bool cur: root.current !== null && root.current.id === modelData.id
                    width: Math.floor(col.width / Math.max(1, root.cats.length)); height: 34; radius: 17
                    color: cur ? Theme.field : (tbm.containsMouse ? Theme.hover : "transparent")
                    Text { anchors.centerIn: parent; text: tab.modelData.icon; font.family: Theme.emojiFont; font.pixelSize: 17; opacity: tab.cur ? 1 : 0.55 }
                    MouseArea { id: tbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.cat = tab.modelData.id; flick.contentY = 0 } }
                    Accessible.name: tab.modelData.label
                }
            }
        }

        Text {
            width: parent.width; leftPadding: 4
            text: root.searching ? (root.shown.length ? I18n.tr("Resultados") : I18n.tr("Sin resultados")) : (root.current ? root.current.label : (root.raw ? "" : I18n.tr("Cargando…")))
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold
        }

        Flickable {
            id: flick
            width: parent.width
            height: 5 * 44
            contentHeight: grid.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            Grid {
                id: grid
                columns: 8
                Repeater {
                    model: root.shown
                    delegate: Rectangle {
                        id: cell
                        required property var modelData
                        readonly property string txt: E.textFor(modelData, root.tone)
                        width: Math.floor(flick.width / 8); height: 44; radius: 12
                        color: cm.containsMouse ? Theme.hover : "transparent"
                        Text { anchors.centerIn: parent; text: E.glyph(cell.txt); font.family: Theme.emojiFont; font.pixelSize: 24 }
                        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.pick(cell.modelData) }
                        Accessible.name: cell.modelData.name
                        Accessible.role: Accessible.Button
                    }
                }
            }
        }

        // Aviso discreto tras copiar (el emoji va en su propio texto, con la fuente de emojis).
        Item {
            width: parent.width; height: 20
            Row {
                anchors.centerIn: parent; spacing: 6
                Text { anchors.verticalCenter: parent.verticalCenter; text: root.copied ? I18n.tr("Copiado") : I18n.tr("Clic para copiar · Ctrl+V para pegar"); color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12 }
                Text { anchors.verticalCenter: parent.verticalCenter; visible: root.copied !== ""; text: E.glyph(root.copied); font.family: Theme.emojiFont; font.pixelSize: 14 }
            }
        }
    }
}
