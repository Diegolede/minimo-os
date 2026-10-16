// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import "../Common"

// Fila con título, detalle y un interruptor a la derecha.
Item {
    id: row
    property string text
    property string detail
    property bool checked
    signal toggled(bool v)
    // Crece si el detalle ocupa varias líneas (nunca queda tapado por el interruptor).
    implicitHeight: Math.max(64, col.implicitHeight + 24)
    Column {
        id: col
        anchors.left: parent.left; anchors.leftMargin: 18
        anchors.right: sw.left; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text { width: parent.width; wrapMode: Text.WordWrap; text: row.text; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 14 }
        Text { width: parent.width; wrapMode: Text.WordWrap; text: row.detail; visible: text !== ""; color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12 }
    }
    MSwitch { id: sw; anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; checked: row.checked; onToggled: v => row.toggled(v) }
}
