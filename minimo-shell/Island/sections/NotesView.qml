// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import "../../Common"

// Notas dentro de la isla: lista (título = primera línea) y editor.
// Se guardan solas (Notes, ~/.config/minimo-os/notes.json); "Eliminar" pide confirmación.
Item {
    id: root
    signal back()
    property string editing: ""        // id de la nota abierta ("" = lista)
    property bool armed: false
    implicitHeight: col.implicitHeight

    function reset() { close(); }
    function open(id) { armed = false; editing = id; editor.text = Notes.get(id)?.text ?? ""; editor.forceActiveFocus(); editor.cursorPosition = editor.text.length }
    function close() { if (editing !== "") Notes.flush(); editing = ""; armed = false; editor.focus = false }
    function goBack() { if (editing !== "") close(); else root.back() }
    function stamp(ms) {
        const d = new Date(ms), now = new Date()
        return d.toDateString() === now.toDateString() ? Qt.formatTime(d, "HH:mm") : d.toLocaleDateString(I18n.locale, I18n.lang === "en" ? "MMM d" : "d MMM")
    }

    Timer { id: disarm; interval: 3000; onTriggered: root.armed = false }

    component RoundButton: Rectangle {
        id: rb
        property string icon
        signal clicked()
        width: 32; height: 32; radius: 16
        color: rbm.containsMouse ? Theme.hover : Theme.surface; border.width: 1; border.color: Theme.surfaceBorder
        Icon { anchors.centerIn: parent; name: rb.icon; size: 18 }
        MouseArea { id: rbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rb.clicked() }
    }

    Column {
        id: col
        width: parent.width
        spacing: 12

        Item {
            width: parent.width; height: 32
            RoundButton { icon: "back"; onClicked: root.goBack() }
            Text {
                anchors.centerIn: parent
                text: I18n.tr("Notas")
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold
            }
            RoundButton { anchors.right: parent.right; visible: root.editing === ""; icon: "plus"; onClicked: root.open(Notes.create()) }
            Rectangle {
                anchors.right: parent.right
                visible: root.editing !== ""
                width: dl.implicitWidth + 24; height: 32; radius: 16
                color: root.armed ? Theme.danger : (dm.containsMouse ? Theme.hover : Theme.surface)
                border.width: root.armed ? 0 : 1; border.color: Theme.surfaceBorder
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                Text { id: dl; anchors.centerIn: parent; text: root.armed ? I18n.tr("Confirmar") : I18n.tr("Eliminar"); color: root.armed ? "#FFFFFF" : Theme.textPrimary; font.family: Theme.font; font.pixelSize: 12; font.weight: root.armed ? Font.DemiBold : Font.Normal }
                MouseArea {
                    id: dm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.armed) { root.armed = true; disarm.restart(); return }
                        const id = root.editing; root.editing = ""; root.armed = false; Notes.remove(id)
                    }
                }
            }
        }

        // Lista.
        Text {
            visible: root.editing === "" && Notes.notes.length === 0
            width: parent.width; topPadding: 24; bottomPadding: 24
            horizontalAlignment: Text.AlignHCenter
            text: I18n.tr("Sin notas. Hacé clic en + para escribir una.")
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 13
        }
        Flickable {
            visible: root.editing === "" && Notes.notes.length > 0
            width: parent.width
            height: visible ? Math.min(list.implicitHeight, 380) : 0
            contentHeight: list.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Rectangle {
                id: list
                width: parent.width; implicitHeight: notesCol.implicitHeight; radius: 18
                color: Theme.surface; border.width: 1; border.color: Theme.surfaceBorder
                Column {
                    id: notesCol
                    width: parent.width
                    Repeater {
                        model: Notes.notes
                        delegate: Item {
                            id: nr
                            required property var modelData
                            required property int index
                            width: notesCol.width; height: 56
                            Rectangle { anchors.fill: parent; anchors.margins: 4; radius: 14; color: nm.containsMouse ? Theme.hover : "transparent" }
                            Column {
                                x: 16; width: parent.width - 32 - when.implicitWidth - 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text {
                                    width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
                                    text: Notes.title(nr.modelData.text) || I18n.tr("Nota nueva")
                                    color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.Medium
                                }
                                Text {
                                    width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
                                    visible: text !== ""
                                    text: Notes.preview(nr.modelData.text)
                                    color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12
                                }
                            }
                            Text {
                                id: when
                                anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                                text: root.stamp(nr.modelData.updated)
                                color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12
                            }
                            Rectangle { visible: nr.index < Notes.notes.length - 1; anchors.bottom: parent.bottom; x: 16; width: parent.width - 32; height: 1; color: Theme.track }
                            MouseArea { id: nm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.open(nr.modelData.id) }
                        }
                    }
                }
            }
        }

        // Editor (texto plano; se guarda solo).
        Rectangle {
            visible: root.editing !== ""
            width: parent.width; height: visible ? 300 : 0; radius: 18
            color: Theme.field
            Flickable {
                id: ef
                anchors.fill: parent; anchors.margins: 14
                contentHeight: editor.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                TextEdit {
                    id: editor
                    width: ef.width
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    selectByMouse: true
                    color: Theme.textPrimary; selectionColor: Theme.fill; selectedTextColor: Theme.onAccent
                    font.family: Theme.font; font.pixelSize: 14
                    onTextChanged: if (root.editing !== "" && activeFocus) Notes.edit(root.editing, text)
                    onCursorRectangleChanged: {
                        if (cursorRectangle.y < ef.contentY) ef.contentY = cursorRectangle.y
                        else if (cursorRectangle.y + cursorRectangle.height > ef.contentY + ef.height) ef.contentY = cursorRectangle.y + cursorRectangle.height - ef.height
                    }
                    Keys.onEscapePressed: root.close()
                }
                Text {
                    visible: editor.text === ""
                    text: I18n.tr("Escribí algo…")
                    color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 14
                }
            }
        }
    }
}
