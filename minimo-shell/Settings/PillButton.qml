// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import "../Common"

// Botón píldora: superficie blanca (negra en oscuro) con filete; `outlined` sin relleno; `primary` negro.
Rectangle {
    id: b
    property string text
    property string icon: ""
    property bool outlined: false
    property bool primary: false
    signal clicked()
    width: r.implicitWidth + 32; height: 36; radius: 18
    color: primary ? (m.containsMouse ? Theme.fillHover : Theme.fill) : (m.containsMouse ? Theme.hover : (outlined ? "transparent" : Theme.surface))
    border.width: primary ? 0 : 1; border.color: outlined ? Theme.dot : Theme.surfaceBorder
    Row {
        id: r
        anchors.centerIn: parent; spacing: 8
        Icon { name: b.icon; visible: b.icon !== ""; size: 16; tone: b.primary ? "white" : "dark"; anchors.verticalCenter: parent.verticalCenter }
        Text { text: b.text; color: b.primary ? Theme.onAccent : (b.outlined ? Theme.textSecondary : Theme.textPrimary); font.family: Theme.font; font.pixelSize: 13; font.weight: b.primary ? Font.DemiBold : Font.Normal; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
}
