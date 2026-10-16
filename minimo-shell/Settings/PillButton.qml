// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import "../Common"

// Botón píldora: superficie blanca (negra en oscuro) sin filete; `outlined` sin relleno ni borde (botón de texto); `primary` negro.
Rectangle {
    id: b
    property string text
    property string icon: ""
    property bool outlined: false
    property bool primary: false
    signal clicked()
    width: r.implicitWidth + 32; height: 36; radius: 18
    color: primary ? (m.containsMouse ? Theme.fillHover : Theme.fill) : (m.containsMouse ? Theme.hover : (outlined ? "transparent" : Theme.surface))
    border.width: 0
    activeFocusOnTab: true
    Keys.onReturnPressed: b.clicked()
    Keys.onSpacePressed: b.clicked()
    Rectangle {          // aro de foco por teclado (solo con foco, sin filete permanente)
        anchors.fill: parent; anchors.margins: -3; radius: height / 2
        color: "transparent"; border.width: 2; border.color: Theme.fill
        visible: b.activeFocus
    }
    Row {
        id: r
        anchors.centerIn: parent; spacing: 8
        Icon { name: b.icon; visible: b.icon !== ""; size: 16; tone: b.primary ? "white" : "dark"; anchors.verticalCenter: parent.verticalCenter }
        Text { text: b.text; color: b.primary ? Theme.onAccent : (b.outlined ? Theme.textSecondary : Theme.textPrimary); font.family: Theme.font; font.pixelSize: 13; font.weight: b.primary ? Font.DemiBold : Font.Normal; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
}
