// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import "../../Common"

// Portapapeles dentro de la isla: fijados arriba, historial debajo.
// Clic en un elemento: lo copia y cierra la isla (pegar con Ctrl+V).
Item {
    id: root
    signal back()
    signal picked()
    property bool armed: false        // "Borrar" pide un segundo clic
    implicitHeight: col.implicitHeight

    function refresh() { armed = false; Clipboard.refresh() }
    readonly property var history: Clipboard.items.filter(i => i.binary || !Clipboard.isPinned(i.text))

    Timer { id: disarm; interval: 3000; onTriggered: root.armed = false }

    Column {
        id: col
        width: parent.width
        spacing: 12

        Item {
            width: parent.width; height: 32
            Rectangle {
                width: 32; height: 32; radius: 16
                color: bm.containsMouse ? Theme.hover : Theme.field
                Icon { anchors.centerIn: parent; name: "back"; size: 18 }
                MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.back() }
            }
            Text {
                anchors.centerIn: parent
                text: "Portapapeles"
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold
            }
            Rectangle {
                anchors.right: parent.right
                visible: Clipboard.items.length > 0
                width: cl.implicitWidth + 24; height: 32; radius: 16
                color: root.armed ? Theme.fill : (cm.containsMouse ? Theme.hover : Theme.field)
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                Text { id: cl; anchors.centerIn: parent; text: root.armed ? "Confirmar" : "Borrar"; color: root.armed ? Theme.onAccent : Theme.textPrimary; font.family: Theme.font; font.pixelSize: 12; font.weight: root.armed ? Font.DemiBold : Font.Normal }
                MouseArea {
                    id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { if (!root.armed) { root.armed = true; disarm.restart() } else { root.armed = false; Clipboard.clear() } }
                }
            }
        }

        Flickable {
            id: flick
            width: parent.width
            height: Math.min(list.implicitHeight, 420)
            contentHeight: list.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Column {
                id: list
                width: flick.width
                spacing: 2

                Text {
                    visible: Clipboard.pins.length > 0
                    leftPadding: 14; bottomPadding: 2
                    text: "Fijados"; color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold
                }
                Repeater {
                    model: Clipboard.pins
                    delegate: ClipRow {
                        required property string modelData
                        width: list.width
                        text: modelData
                        pinned: true
                        removable: false
                        onPicked: { Clipboard.copyText(modelData); root.picked() }
                        onPinToggled: Clipboard.unpin(modelData)
                    }
                }
                Item { visible: Clipboard.pins.length > 0 && root.history.length > 0; width: 1; height: 8 }
                Text {
                    visible: Clipboard.pins.length > 0 && root.history.length > 0
                    leftPadding: 14; bottomPadding: 2
                    text: "Recientes"; color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold
                }
                Repeater {
                    model: root.history
                    delegate: ClipRow {
                        required property var modelData
                        width: list.width
                        text: modelData.text
                        binary: modelData.binary
                        onPicked: { Clipboard.copy(modelData); root.picked() }
                        onPinToggled: Clipboard.pin(modelData)
                        onRemoveRequested: Clipboard.remove(modelData)
                    }
                }
            }
        }

        Text {
            visible: Clipboard.pins.length === 0 && root.history.length === 0
            width: parent.width
            topPadding: 18; bottomPadding: 18
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: Clipboard.available ? "Lo que copies aparece acá." : "Falta cliphist para guardar el historial."
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 13
        }
    }
}
