// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import "../Common"

// Fila de un atajo: acción a la izquierda y sus combinaciones (teclas) a la derecha.
// combos: [{ mods: ["Super", "Shift"], keys: ["←", "H"] }, …]. Teclas alternativas con
// los mismos modificadores se separan con "/"; combinaciones distintas, con "o".
Item {
    id: row
    property string label
    property var combos: []
    property bool last: false
    implicitHeight: Math.max(44, name.implicitHeight + 22)

    Text {
        id: name
        anchors.left: parent.left; anchors.leftMargin: 18
        anchors.right: keys.left; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: row.label
        wrapMode: Text.WordWrap
        color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 14
    }
    Row {
        id: keys
        anchors.right: parent.right; anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        Repeater {
            model: row.combos
            delegate: Row {
                id: combo
                required property var modelData
                required property int index
                spacing: 4
                Text {
                    visible: combo.index > 0
                    anchors.verticalCenter: parent.verticalCenter
                    rightPadding: 6
                    text: I18n.tr("o"); color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12
                }
                Repeater {
                    model: combo.modelData.mods
                    delegate: KeyCap { required property string modelData; text: modelData }
                }
                Repeater {
                    model: combo.modelData.keys
                    delegate: Row {
                        id: alt
                        required property string modelData
                        required property int index
                        spacing: 4
                        Text {
                            visible: alt.index > 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: "/"; color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12
                        }
                        KeyCap { text: alt.modelData }
                    }
                }
            }
        }
    }
    Rectangle {
        visible: !row.last
        anchors.bottom: parent.bottom
        x: 18; width: parent.width - 18; height: 1
        color: Theme.track
    }
}
