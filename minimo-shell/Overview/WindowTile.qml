// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../Common"

// Una ventana en la vista: captura (un solo cuadro, no en vivo) o, si no hay captura,
// el icono de la app sobre gris claro. Debajo, icono + título. Seleccionada: contorno negro.
Item {
    id: tile
    property var source: null            // Toplevel de Wayland (para la captura)
    property string title
    property string icon                 // ruta del icono de la app
    property string badge                // "Escritorio 2" si no es el actual
    property real aspect: 16 / 10
    property bool selected: false
    property bool capture: true
    signal picked()
    signal hovered()

    readonly property real frameH: height - 30
    readonly property real frameW: Math.min(width, frameH * aspect)

    Item {
        id: frame
        anchors.horizontalCenter: parent.horizontalCenter
        width: tile.frameW; height: Math.min(tile.frameH, tile.frameW / tile.aspect)
        y: (tile.frameH - height) / 2
        scale: ma.pressed ? 0.98 : 1
        Behavior on scale { NumberAnimation { duration: 120 } }

    // ClippingRectangle recorta el contenido a las esquinas redondeadas (shader propio de
    // Quickshell, sin capa intermedia): la captura, el icono y la etiqueta quedan dentro.
    ClippingRectangle {
        id: clipBox
        anchors.fill: parent
        radius: 14
        color: Theme.field

        ScreencopyView {
            id: shot
            anchors.fill: parent
            visible: hasContent
            captureSource: tile.capture ? tile.source : null
            live: false
        }
        Image {
            anchors.centerIn: parent
            visible: !shot.hasContent
            width: Math.min(64, parent.height * 0.4); height: width
            sourceSize: Qt.size(128, 128)
            source: tile.icon
            asynchronous: true
        }
        Rectangle {
            visible: tile.badge !== ""
            anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 8
            width: bt.implicitWidth + 16; height: 22; radius: 11
            color: Theme.card
            Text { id: bt; anchors.centerIn: parent; text: tile.badge; color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 11 }
        }
    }
        // Borde y selección por encima del contenido recortado, con el mismo radio.
        Rectangle {
            anchors.fill: parent
            radius: clipBox.radius
            color: "transparent"
            border.width: tile.selected ? 3 : 1
            border.color: tile.selected ? Theme.fill : Theme.track
            Behavior on border.width { NumberAnimation { duration: 120 } }
        }
    }
    // Título pegado a la captura (no al fondo de la celda): misma distancia en todas.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: frame.bottom; anchors.topMargin: 10
        spacing: 6
        width: Math.min(implicitWidth, tile.width)
        Image { width: 16; height: 16; sourceSize: Qt.size(32, 32); source: tile.icon; anchors.verticalCenter: parent.verticalCenter }
        Text {
            width: Math.min(implicitWidth, tile.width - 22)
            text: tile.title; elide: Text.ElideRight
            color: tile.selected ? Theme.textPrimary : Theme.textSecondary
            font.family: Theme.font; font.pixelSize: 13; font.weight: tile.selected ? Font.DemiBold : Font.Normal
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tile.hovered()
        onClicked: tile.picked()
    }
}
