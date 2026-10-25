// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import "../../Common"

// Cuatro barritas de señal (0..100).
Row {
    id: sb
    property int signal: 0
    property color on: Theme.textPrimary
    spacing: 2
    Repeater {
        model: 4
        delegate: Rectangle {
            required property int index
            anchors.bottom: sb.bottom
            width: 3; height: 4 + index * 3; radius: 1.5
            color: sb.signal > index * 25 ? sb.on : Theme.track
        }
    }
}
