// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import "../Common"

// Medidor de la mascota: icono, nombre, estado en palabras y barra fina (rojo si está bajo).
Item {
    id: m
    property string icon
    property string label
    property real frac: 1
    readonly property bool low: frac < 0.25
    readonly property string word: frac >= 0.75 ? "Muy bien" : frac >= 0.5 ? "Bien" : frac >= 0.25 ? "Bajo" : "Muy bajo"
    implicitHeight: 52

    Icon { x: 14; y: 11; name: m.icon; size: 18; tone: "dark" }
    Text {
        x: 44; y: 11; height: 18; verticalAlignment: Text.AlignVCenter
        text: m.label; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 14
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 14
        y: 11; height: 18; verticalAlignment: Text.AlignVCenter
        text: m.word; color: m.low ? Theme.danger : Theme.textSecondary; font.family: Theme.font; font.pixelSize: 13
    }
    Rectangle {
        x: 14; y: 38; width: parent.width - 28; height: 4; radius: 2; color: Theme.track
        Rectangle {
            height: parent.height; radius: 2
            width: parent.width * Math.max(0, Math.min(1, m.frac))
            color: m.low ? Theme.danger : Theme.fill
            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        }
    }
}
