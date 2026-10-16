// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "../Common"

// Miniatura de un fondo. Al pasar el mouse aparece un botón para quitarlo: el primer clic
// lo arma (negro, "Eliminar"/"Quitar"), el segundo dentro de 3 s confirma.
// `owned`: está en ~/Imágenes/Fondos → se manda a la papelera; si no, solo se quita de la lista.
Item {
    id: tile
    required property string modelData
    readonly property string path: modelData
    property bool owned: false
    readonly property bool current: path === DisplayState.wallpaper
    property bool armed: false
    signal picked()
    signal removeRequested()

    Image {
        id: thumb
        anchors.fill: parent; anchors.margins: 4
        source: "file://" + tile.path
        sourceSize: Qt.size(400, 250)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    Item {
        id: mask
        anchors.fill: thumb
        visible: false
        layer.enabled: true
        layer.smooth: true
        Rectangle { anchors.fill: parent; radius: 14; antialiasing: true }
    }
    Rectangle { anchors.fill: thumb; radius: 14; color: Theme.field }
    MultiEffect {
        anchors.fill: thumb
        source: thumb
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        opacity: tile.armed ? 0.55 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
    }
    Rectangle {
        anchors.fill: parent; radius: 18
        color: "transparent"
        border.width: tile.current ? 2.5 : (hover.hovered ? 1.5 : 0)
        border.color: tile.current ? Theme.textPrimary : Theme.track
        antialiasing: true
    }
    HoverHandler { id: hover }
    MouseArea {
        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
        onClicked: { tile.armed = false; tile.picked() }
    }

    // Botón quitar (arriba a la derecha).
    Rectangle {
        id: rm
        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10
        height: 26; radius: 13
        width: tile.armed ? lbl.implicitWidth + 36 : 26
        color: tile.armed ? Theme.fill : (rmm.containsMouse ? Theme.cardSolid : Qt.rgba(Theme.cardSolid.r, Theme.cardSolid.g, Theme.cardSolid.b, 0.88))
        opacity: hover.hovered || tile.armed ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        // "×" dibujada
        Item {
            id: cross
            width: 26; height: 26
            anchors.right: parent.right
            Repeater {
                model: [45, -45]
                Rectangle {
                    required property int modelData
                    anchors.centerIn: parent; width: 10; height: 1.6; radius: 0.8
                    rotation: modelData; antialiasing: true
                    color: tile.armed ? Theme.onAccent : Theme.textPrimary
                }
            }
        }
        Text {
            id: lbl
            anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
            text: tile.owned ? I18n.tr("Eliminar") : I18n.tr("Quitar")
            color: Theme.onAccent; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold
            opacity: tile.armed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        }
        MouseArea {
            id: rmm
            anchors.fill: parent; anchors.margins: -4
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!tile.armed) { tile.armed = true; disarm.restart(); return }
                tile.armed = false; tile.removeRequested()
            }
        }
    }
    Timer { id: disarm; interval: 3000; onTriggered: tile.armed = false }
}
