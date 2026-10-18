// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../../Common"

// Vista de escritorios dentro de la isla: grilla de workspaces con los iconos
// de sus ventanas, el activo con contorno negro, y un "+" para uno nuevo.
// Ventanas (cada icono es UNA ventana, también en apps con varias o agrupadas):
//   clic → enfocarla · mantener o arrastrar → llevarla a otro escritorio (o al "+")
//   × al pasar el mouse → cerrarla (cierre amable de Hyprland, nunca kill)
//   Esc o soltar fuera de un escritorio → cancelar. Antes de actuar, window-action.py
//   vuelve a consultar a Hyprland: si la ventana ya no existe, no hace nada.
Item {
    id: root
    signal back()
    signal picked()
    implicitHeight: col.implicitHeight

    function refresh() { cancelDrag(); notice = ""; Hyprland.refreshToplevels(); Hyprland.refreshWorkspaces() }

    // --- Arrastre de una ventana ---
    property string dragAddr: ""          // dirección de la ventana arrastrada ("" = ninguna)
    property string dragIcon: ""
    property int dragFrom: -1             // escritorio de origen
    property real ghostX: 0               // centro del icono flotante (coordenadas de la grilla)
    property real ghostY: 0
    property var target: null             // id de escritorio, "new" (el +) o null
    property string notice: ""
    readonly property bool windowDrag: dragAddr !== ""
    readonly property string actionScript: Qt.resolvedUrl("../../scripts/window-action.py").toString().replace("file://", "")

    function startDrag(addr, icon, fromWs, gx, gy) {
        dragAddr = addr; dragIcon = icon; dragFrom = fromWs; notice = ""
        moveDrag(gx, gy)
        keyCatcher.forceActiveFocus()              // Esc cancela el arrastre (no cierra la isla)
    }
    function moveDrag(gx, gy) { ghostX = gx; ghostY = gy; target = grid.targetAt(gx, gy) }
    function cancelDrag() { dragAddr = ""; target = null; dragFrom = -1 }
    function dropDrag() {
        const addr = dragAddr, t = target, from = dragFrom
        cancelDrag()
        if (!addr || t === null || t === from) return            // fuera o mismo escritorio: cancelar
        act(["move", addr, t === "new" ? "emptynm" : String(t)])
    }
    function closeWindow(addr) { if (addr) act(["close", addr]) }
    function focusWindow(addr) {
        const a = String(addr).startsWith("0x") ? addr : "0x" + addr
        if (!/^0x[0-9a-fA-F]+$/.test(a)) return
        Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.focus({ window = "address:' + a + '" })'])
        root.picked()
    }
    function act(args) {
        if (actProc.running) return                               // una acción a la vez
        actProc.command = ["python3", root.actionScript].concat(args)
        actProc.running = true
    }
    Process {
        id: actProc
        stdout: StdioCollector {
            onStreamFinished: {
                let r = null
                try { r = JSON.parse(text) } catch (e) { r = null }
                if (r && !r.ok && r.reason === "gone") root.notice = I18n.tr("Esa ventana ya no existe.")
                else if (!r || !r.ok) root.notice = I18n.tr("No se pudo completar la acción.")
                Hyprland.refreshToplevels(); Hyprland.refreshWorkspaces()
            }
        }
    }
    Timer { running: root.notice !== ""; interval: 2600; onTriggered: root.notice = "" }
    // Si la ventana arrastrada desaparece (se cerró sola), el arrastre se cancela.
    Connections {
        target: Hyprland.toplevels
        function onValuesChanged() {
            if (root.windowDrag && !Hyprland.toplevels.values.some(t => String(t.address) === root.dragAddr)) root.cancelDrag()
        }
    }
    Item { id: keyCatcher; Keys.onEscapePressed: e => { if (root.windowDrag) { root.cancelDrag(); e.accepted = true } else e.accepted = false } }

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
            // Destino de una ventana soltada en (px, py): un escritorio, "new" (el +) o null.
            function targetAt(px, py) {
                if (px < 0 || py < 0 || px > width || py > height) return null
                const c = Math.floor(px / (tileW + gap)), r = Math.floor(py / (tileH + gap))
                if (c >= columns || px - c * (tileW + gap) > tileW || py - r * (tileH + gap) > tileH) return null   // en un hueco
                const i = r * columns + c
                if (i < root.order.length) return root.order[i]
                return i === root.order.length ? "new" : null
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
                    readonly property bool dropTarget: root.windowDrag && root.target === modelData.id && modelData.id !== root.dragFrom
                    readonly property bool validTarget: root.windowDrag && modelData.id !== root.dragFrom
                    color: dropTarget ? Theme.fill : (tileMouse.containsMouse || dragging || validTarget ? Theme.hover : Theme.surface)
                    opacity: root.windowDrag && modelData.id === root.dragFrom ? 0.6 : 1
                    border.width: active && !dropTarget ? 2 : 0
                    border.color: Theme.textPrimary
                    Behavior on x { enabled: !tile.dragging && !root.snap; NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                    Behavior on y { enabled: !tile.dragging && !root.snap; NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Text {
                        x: 10; y: 8
                        text: tile.modelData.name || tile.modelData.id
                        color: tile.dropTarget ? Theme.onAccent : Theme.textSecondary; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.Medium
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
                    // Una ventana por icono (hasta 4; con más, 3 y "+N").
                    Row {
                        anchors.centerIn: parent; anchors.verticalCenterOffset: 6
                        spacing: 6
                        readonly property var wins: tile.modelData.toplevels ? tile.modelData.toplevels.values : []
                        readonly property int shownN: wins.length > 4 ? 3 : wins.length
                        Repeater {
                            model: parent.wins.slice(0, parent.shownN)
                            delegate: Item {
                                id: winItem
                                required property var modelData
                                readonly property string addr: String(modelData.address)
                                readonly property string icon: root.iconFor(modelData)
                                readonly property bool lifted: root.dragAddr === addr
                                width: 26; height: 26
                                Image {
                                    anchors.centerIn: parent
                                    width: 24; height: 24; sourceSize: Qt.size(48, 48)
                                    source: winItem.icon
                                    opacity: winItem.lifted ? 0.25 : 1
                                    scale: wm.pressed && !winItem.lifted ? 0.9 : 1
                                    Behavior on scale { NumberAnimation { duration: 120 } }
                                }
                                MouseArea {
                                    id: wm
                                    anchors.fill: parent; anchors.margins: -2
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: root.windowDrag ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    property real px: 0; property real py: 0
                                    function gpos(m) { return mapToItem(grid, m.x, m.y) }
                                    onPressed: m => { px = m.x; py = m.y; hold.restart() }
                                    onPositionChanged: m => {
                                        const g = gpos(m)
                                        if (winItem.lifted) root.moveDrag(g.x, g.y)
                                        else if (pressed && !root.windowDrag && Math.hypot(m.x - px, m.y - py) > 6) { hold.stop(); root.startDrag(winItem.addr, winItem.icon, tile.modelData.id, g.x, g.y) }
                                    }
                                    onReleased: { hold.stop(); if (winItem.lifted) root.dropDrag() }
                                    onCanceled: { hold.stop(); if (winItem.lifted) root.cancelDrag() }
                                    onClicked: if (!winItem.lifted && !root.windowDrag) root.focusWindow(winItem.addr)
                                    Timer {
                                        id: hold; interval: 380
                                        onTriggered: if (wm.pressed && !root.windowDrag) { const g = wm.mapToItem(grid, wm.px, wm.py); root.startDrag(winItem.addr, winItem.icon, tile.modelData.id, g.x, g.y) }
                                    }
                                }
                                // Cerrar: × al pasar el mouse (no durante un arrastre).
                                Rectangle {
                                    visible: (wm.containsMouse || xm.containsMouse) && !root.windowDrag
                                    // En la esquina, casi fuera del icono: no tapa el punto donde se agarra la ventana.
                                    x: parent.width - 6; y: -10
                                    width: 16; height: 16; radius: 8
                                    color: xm.containsMouse ? Theme.fillHover : Theme.fill
                                    Icon { anchors.centerIn: parent; name: "dismiss"; size: 10; tone: "white" }
                                    MouseArea { id: xm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.closeWindow(winItem.addr) }
                                    Accessible.name: I18n.tr("Cerrar ventana")
                                    Accessible.role: Accessible.Button
                                }
                            }
                        }
                        Text {
                            visible: parent.wins.length > parent.shownN
                            anchors.verticalCenter: parent.verticalCenter
                            text: "+" + (parent.wins.length - parent.shownN)
                            color: tile.dropTarget ? Theme.onAccent : Theme.textSecondary; font.family: Theme.font; font.pixelSize: 11
                        }
                    }
                }
            }
            Rectangle {
                x: grid.slotX(root.order.length); y: grid.slotY(root.order.length)
                width: grid.tileW; height: grid.tileH; radius: 14
                Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                readonly property bool dropTarget: root.windowDrag && root.target === "new"
                color: dropTarget ? Theme.fill : (root.windowDrag ? Theme.hover : "transparent")
                border.width: root.windowDrag ? 0 : 1.5; border.color: plusMouse.containsMouse ? Theme.textSecondary : Theme.track
                Icon { anchors.centerIn: parent; name: "plus"; tone: parent.dropTarget ? "white" : "gray"; size: 22 }
                MouseArea {
                    id: plusMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { Workspaces.goEmpty(); root.picked() }
                }
            }
            // Ventana arrastrada: su icono sigue al puntero.
            Image {
                visible: root.windowDrag
                z: 20
                x: root.ghostX - width / 2; y: root.ghostY - height / 2
                width: 34; height: 34; sourceSize: Qt.size(68, 68)
                source: root.dragIcon
            }
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.notice !== "" ? root.notice
                : root.windowDrag ? I18n.tr("Soltala en otro escritorio para moverla · Esc cancela")
                : I18n.tr("Arrastrá un escritorio para reordenarlo, o una app para llevarla a otro")
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 11
        }
    }
}
