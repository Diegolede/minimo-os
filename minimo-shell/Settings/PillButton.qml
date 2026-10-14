// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import "../Common"

// Botón píldora (gris claro, blanco si `raised`, con borde si `outlined`; negro si `primary`).
Rectangle {
    id: b
    property string text
    property string icon: ""
    property bool outlined: false
    property bool primary: false
    property bool raised: false        // sobre una tarjeta gris: fondo blanco
    signal clicked()
    width: r.implicitWidth + 32; height: 36; radius: 18
    color: primary ? (m.containsMouse ? Theme.fillHover : Theme.fill) : (m.containsMouse ? Theme.hover : (outlined ? "transparent" : raised ? Theme.raised : Theme.field))
    border.width: outlined ? 1 : 0; border.color: Theme.track
    Row {
        id: r
        anchors.centerIn: parent; spacing: 8
        Icon { name: b.icon; visible: b.icon !== ""; size: 16; tone: b.primary ? "white" : "dark"; anchors.verticalCenter: parent.verticalCenter }
        Text { text: b.text; color: b.primary ? Theme.onAccent : (b.outlined ? Theme.textSecondary : Theme.textPrimary); font.family: Theme.font; font.pixelSize: 13; font.weight: b.primary ? Font.DemiBold : Font.Normal; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
}
