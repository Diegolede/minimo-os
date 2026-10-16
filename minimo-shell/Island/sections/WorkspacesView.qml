// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../Common"

// Vista de escritorios dentro de la isla: grilla de workspaces con los iconos
// de sus ventanas, el activo con contorno negro, y un "+" para uno nuevo.
Item {
    id: root
    signal back()
    signal picked()
    implicitHeight: col.implicitHeight

    function refresh() { Hyprland.refreshToplevels(); Hyprland.refreshWorkspaces() }

    // Orden visual (IDs). Sigue a Hyprland salvo mientras se arrastra.
    property var order: []
    property bool dragged: false
    property bool snap: false        // reacomodo instantáneo tras reordenar (sin animar de vuelta)
    Connections {
        target: Workspaces
        function onReordered() { root.snap = true; root.order = root.ids; Qt.callLater(() => root.snap = false) }
    }
    readonly property var ids: Workspaces.list.map(w => w.id)
    onIdsChanged: if (!dragged) order = ids
    Component.onCompleted: order = ids
    function moveTo(id, slot) {
        dragged = true
        const from = order.indexOf(id)
        if (from < 0 || from === slot) return
        const o = order.slice(); o.splice(from, 1); o.splice(slot, 0, id)
        order = o
    }
    function commit() {
        const o = order
        // Sin cambios: nada que hacer. Con cambios: mover ventanas en Hyprland.
        if (o.length === ids.length && !o.every((id, i) => id === ids[i])) Workspaces.reorder(o)
        else order = ids
    }

    function iconFor(t) {
        let cls = ""
        if (t.wayland && t.wayland.appId) cls = t.wayland.appId
        else if (t.lastIpcObject && t.lastIpcObject["class"]) cls = t.lastIpcObject["class"]
        const e = cls ? DesktopEntries.heuristicLookup(cls) : null
        const p = Quickshell.iconPath(e ? e.icon : cls, true)
        return p !== "" ? p : Qt.resolvedUrl("../../assets/icons/gray/apps.svg")
    }

    Column {
        id: col
        width: parent.width
        spacing: 16

        Item {
            width: parent.width; height: 32
            Rectangle {
                id: backBtn
                width: 32; height: 32; radius: 16
                color: backMouse.containsMouse ? Theme.hover : Theme.surface
                Icon { anchors.centerIn: parent; name: "back"; size: 18 }
                MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.back() }
            }
            Text {
                anchors.centerIn: parent
                text: I18n.tr("Escritorios")
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold
            }
        }

        // Teselas en posiciones calculadas (no Grid) para poder arrastrarlas: mantener y
        // arrastrar un escritorio lo reordena; los demás se corren con easing en vivo.
        // Al soltar en otra posición, el contenido se mueve de verdad en Hyprland.
        Item {
            id: grid
            readonly property int columns: 3
            readonly property int gap: 8
            readonly property int tileH: 76
            readonly property real tileW: (col.width - gap * (columns - 1)) / columns
            width: col.width
            height: Math.ceil((root.order.length + 1) / columns) * (tileH + gap) - gap
            function slotX(i) { return (i % columns) * (tileW + gap) }
            function slotY(i) { return Math.floor(i / columns) * (tileH + gap) }
            function slotAt(px, py) {
                // px, py: centro de la tesela arrastrada
                const c = Math.max(0, Math.min(columns - 1, Math.floor(px / (tileW + gap))))
                const r = Math.max(0, Math.floor(py / (tileH + gap)))
                return Math.min(root.order.length - 1, r * columns + c)
            }

            Repeater {
                model: Workspaces.list
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    readonly property bool active: modelData.id === Workspaces.activeId
                    readonly property int slot: Math.max(0, root.order.indexOf(modelData.id))
                    readonly property bool dragging: tileMouse.drag.active
                    width: grid.tileW; height: grid.tileH; radius: 14
                    x: grid.slotX(slot); y: grid.slotY(slot)
                    z: dragging ? 10 : 0
                    scale: dragging ? 1.04 : 1
                    color: tileMouse.containsMouse || dragging ? Theme.hover : Theme.surface
                    border.width: active ? 2 : 0
                    border.color: Theme.textPrimary
                    Behavior on x { enabled: !tile.dragging && !root.snap; NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                    Behavior on y { enabled: !tile.dragging && !root.snap; NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Text {
                        x: 10; y: 8
                        text: tile.modelData.name || tile.modelData.id
                        color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.Medium
                    }
                    Row {
                        anchors.centerIn: parent; anchors.verticalCenterOffset: 6
                        spacing: 6
                        Repeater {
                            model: tile.modelData.toplevels ? tile.modelData.toplevels.values.slice(0, 4) : []
                            delegate: Image {
                                required property var modelData
                                width: 24; height: 24; sourceSize: Qt.size(48, 48)
                                source: root.iconFor(modelData)
                            }
                        }
                    }
                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                        drag.target: tile
                        drag.threshold: 6
                        drag.minimumX: 0; drag.maximumX: grid.width - tile.width
                        drag.minimumY: 0; drag.maximumY: grid.height - tile.height
                        onPositionChanged: if (drag.active) root.moveTo(tile.modelData.id, grid.slotAt(tile.x + tile.width / 2, tile.y + tile.height / 2))
                        onReleased: {
                            if (tile.dragging || root.dragged) {
                                Qt.callLater(() => root.dragged = false)   // que el clic no cuente
                                tile.x = Qt.binding(() => grid.slotX(tile.slot)); tile.y = Qt.binding(() => grid.slotY(tile.slot))
                                root.commit()
                            }
                        }
                        onClicked: if (!root.dragged) { Workspaces.goTo(tile.modelData.id); root.picked() }
                    }
                }
            }
            Rectangle {
                x: grid.slotX(root.order.length); y: grid.slotY(root.order.length)
                width: grid.tileW; height: grid.tileH; radius: 14
                Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                color: "transparent"
                border.width: 1.5; border.color: plusMouse.containsMouse ? Theme.textSecondary : Theme.track
                Icon { anchors.centerIn: parent; name: "plus"; tone: "gray"; size: 22 }
                MouseArea {
                    id: plusMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { Workspaces.goEmpty(); root.picked() }
                }
            }
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: I18n.tr("Arrastrá un escritorio para reordenarlo")
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 11
        }
    }
}
