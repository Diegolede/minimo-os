// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Common"

// Vista de ventanas (Super+Tab), estilo Exposé, en el monitor enfocado.
// Ventanas del escritorio actual primero y luego las demás (con su escritorio).
// Orden por uso reciente; empieza en la anterior, así Super+Tab + soltar alterna.
// Captura de cada ventana UNA vez al abrir (no en vivo); sin captura, icono de la app.
PanelWindow {
    id: win
    readonly property bool open: OverviewState.open
    property real t: open ? 1 : 0
    Behavior on t { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }

    screen: Quickshell.screens.find(s => s.name === (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")) ?? Quickshell.screens[0]
    visible: open || t > 0.01
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "minimo-overview"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property var windows: []

    function iconFor(t) {
        const cls = t.lastIpcObject && t.lastIpcObject["class"] ? t.lastIpcObject["class"] : (t.wayland && t.wayland.appId ? t.wayland.appId : "")
        const e = cls ? DesktopEntries.heuristicLookup(cls) : null
        const p = Quickshell.iconPath(e ? e.icon : cls, true)
        return p !== "" ? p : Qt.resolvedUrl("../assets/icons/gray/apps.svg")
    }
    function build() {
        const cur = Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace ? Hyprland.focusedMonitor.activeWorkspace.id : -1
        const list = []
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject || {}
            const ws = t.workspace ? t.workspace.id : (o.workspace ? o.workspace.id : 0)
            if (ws <= 0) continue                      // escritorios especiales (minimizadas, etc.)
            const size = o.size || [16, 10]
            list.push({
                title: t.title || o.title || "",
                icon: iconFor(t),
                badge: ws === cur ? "" : I18n.tr("Escritorio %1", ws),
                aspect: size[1] > 0 ? Math.max(0.5, Math.min(3, size[0] / size[1])) : 1.6,
                source: t.wayland,
                address: t.address,
                cur: ws === cur,
                hist: o.focusHistoryID ?? 999
            })
        }
        list.sort((a, b) => (b.cur - a.cur) || (a.hist - b.hist))
        windows = list
        grid.selected = list.length > 1 && list[1].cur ? 1 : 0
    }
    function focusWindow(i) {
        const w = windows[i]
        OverviewState.hide()
        if (!w) return
        const a = String(w.address).startsWith("0x") ? w.address : "0x" + w.address
        Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.focus({ window = "address:' + a + '" })'])
    }

    onOpenChanged: {
        if (!open) { windows = []; return }        // suelta las capturas
        Hyprland.refreshToplevels()
        buildLater.restart()
    }
    // Un instante para que llegue la lista actualizada de Hyprland (un solo pedido).
    Timer { id: buildLater; interval: 60; onTriggered: { win.build(); keys.forceActiveFocus() } }
    Connections { target: OverviewState; function onNext() { grid.move(1, 0) } }

    Rectangle {
        anchors.fill: parent
        color: Theme.dark ? Qt.rgba(0, 0, 0, 0.55 * win.t) : Qt.rgba(0.96, 0.96, 0.97, 0.82 * win.t)
        MouseArea { anchors.fill: parent; onClicked: OverviewState.hide() }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        opacity: win.t
        scale: 0.97 + 0.03 * win.t
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) OverviewState.hide()
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) win.focusWindow(grid.selected)
            else if (e.key === Qt.Key_Backtab || (e.key === Qt.Key_Tab && (e.modifiers & Qt.ShiftModifier)) || e.key === Qt.Key_Left) grid.move(-1, 0)
            else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Right) grid.move(1, 0)
            else if (e.key === Qt.Key_Up) grid.move(0, -1)
            else if (e.key === Qt.Key_Down) grid.move(0, 1)
            else return
            e.accepted = true
        }
        // Soltar Super (si se abrió con Super+Tab) enfoca la seleccionada.
        Keys.onReleased: e => { if (e.key === Qt.Key_Super_L || e.key === Qt.Key_Super_R || e.key === Qt.Key_Meta) { if (win.windows.length > 0) win.focusWindow(grid.selected) } }

        OverviewGrid {
            id: grid
            anchors.fill: parent
            anchors.margins: 72
            anchors.topMargin: 96
            windows: win.windows
            capture: win.open
            onPicked: i => win.focusWindow(i)
        }
        Text {
            anchors.centerIn: parent
            visible: win.windows.length === 0
            text: I18n.tr("No hay ventanas abiertas")
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 15
        }
    }
}
