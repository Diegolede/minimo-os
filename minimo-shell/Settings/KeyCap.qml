// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import "../Common"

// Tecla dibujada: chip blanco con borde fino, como en los atajos de macOS.
Rectangle {
    id: cap
    property string text
    implicitWidth: Math.max(26, label.implicitWidth + 16)
    implicitHeight: 24
    radius: 7
    color: Theme.raised
    border.width: 1
    border.color: Theme.track
    Text {
        id: label
        anchors.centerIn: parent
        text: cap.text
        color: Theme.textPrimary
        font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium
    }
}
