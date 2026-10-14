// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import "../../Common"

// Elemento del portapapeles: texto (2 líneas como máximo) o "Imagen".
// Clic: copiar. Al pasar el mouse: fijar/soltar y quitar.
Rectangle {
    id: row
    property string text
    property bool binary: false
    property bool pinned: false
    property bool removable: true
    signal picked()
    signal pinToggled()
    signal removeRequested()

    // "[[ binary data 182 KiB png 1920x1080 ]]" → "Imagen PNG · 1920 × 1080".
    function imageText() {
        const m = row.text.match(/binary data .*?(\w+)\s+(\d+)x(\d+)/)
        return m ? "Imagen " + m[1].toUpperCase() + " · " + m[2] + " × " + m[3] : "Imagen"
    }

    implicitHeight: Math.max(44, label.implicitHeight + 22)
    radius: 12
    color: hov.hovered ? Theme.hover : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    HoverHandler { id: hov }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: row.picked() }

    Text {
        id: label
        anchors.left: parent.left; anchors.leftMargin: 14
        anchors.right: tools.left; anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: row.binary ? row.imageText() : row.text.replace(/\s+/g, " ").trim()
        maximumLineCount: 2
        wrapMode: Text.Wrap
        elide: Text.ElideRight
        color: row.binary ? Theme.textSecondary : Theme.textPrimary
        font.family: Theme.font; font.pixelSize: 13
    }
    Row {
        id: tools
        anchors.right: parent.right; anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        // Siempre visible si está fijado; si no, solo al pasar el mouse.
        Rectangle {
            visible: !row.binary && (row.pinned || hov.hovered)
            width: 30; height: 30; radius: 15
            color: pm.containsMouse ? Theme.field : "transparent"
            Icon { anchors.centerIn: parent; name: "pin"; size: 16; tone: row.pinned ? "dark" : "gray" }
            MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: row.pinToggled() }
        }
        Rectangle {
            visible: row.removable && hov.hovered
            width: 30; height: 30; radius: 15
            color: xm.containsMouse ? Theme.field : "transparent"
            // × dibujada (dos trazos), como en las miniaturas de fondos.
            Repeater {
                model: [45, -45]
                delegate: Rectangle {
                    required property int modelData
                    anchors.centerIn: parent; width: 11; height: 1.6; radius: 0.8
                    rotation: modelData; color: Theme.textSecondary
                }
            }
            MouseArea { id: xm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: row.removeRequested() }
        }
    }
}
