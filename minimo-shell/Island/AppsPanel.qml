// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../Common"
import "../Character"

// Panel "En segundo plano" (deslizar la isla de derecha a izquierda): las apps de la
// bandeja del sistema (Steam, Discord…), como los iconos ocultos de Windows 11.
// Clic = pedir Activate y, si la app lo ignora, enfocar su ventana o relanzarla (ver scripts/tray-open.py).
Item {
    id: root
    property bool open: false
    implicitHeight: col.implicitHeight + 32

    onOpenChanged: { menuFor = null; if (open) greetLater.restart() }

    // Menú contextual (clic derecho): el de la propia app, dentro del panel. Uno a la vez.
    property var menuFor: null
    focus: menuFor !== null
    Keys.onEscapePressed: menuFor = null
    // Clic en cualquier otro lugar del panel cierra el menú.
    MouseArea { anchors.fill: parent; enabled: root.menuFor !== null; onClicked: root.menuFor = null }
    function quit(i) {
        Quickshell.execDetached([Qt.resolvedUrl("../scripts/tray-open.py").toString().replace("file://", ""), "--quit", i.id])
        menuFor = null
    }
    function trigger(e) {
        e.triggered()
        menuFor = null
        CharacterBus.islandCommand("close")
    }
    Timer { id: greetLater; interval: 280; onTriggered: chr.react("greet") }

    // Tocar SystemTray siempre registra el StatusNotifierWatcher, así las apps publican
    // su icono aunque el panel esté cerrado. La lista solo se enlaza con el panel abierto.
    readonly property var trayItems: SystemTray.items.values
    readonly property var items: open ? trayItems.filter(i => !!i) : []
    // Si la app del menú abierto desaparece (p. ej. tras "Salir"), olvidar el menú.
    onItemsChanged: if (menuFor && items.indexOf(menuFor) < 0) menuFor = null

    // Ids SNI crudos ("Grok Bot_status_icon_1", "chrome_status_icon_1", "steam-2") → nombre limpio.
    function cleanId(s) {
        return (s || "").replace(/_status_icon_\d+$/i, "").replace(/[-_ ]\d+$/, "").replace(/[_-]+/g, " ").trim()
    }
    function entryOf(i) {
        for (const k of [cleanId(i.id), i.id, i.title, i.tooltipTitle]) {
            if (!k) continue
            const e = DesktopEntries.heuristicLookup(k) || DesktopEntries.byId(k.toLowerCase().replace(/ /g, "-"))
            if (e) return e
        }
        return null
    }
    function nameOf(i) {
        const e = entryOf(i)
        if (e && e.name) return e.name
        const n = i.title || i.tooltipTitle || cleanId(i.id)
        return n.replace(/\b\w/g, c => c.toUpperCase())
    }
    function entryIcon(i) { const e = entryOf(i); return e ? Quickshell.iconPath(e.icon, true) : "" }
    function iconOf(i) { return i.icon ? i.icon : entryIcon(i) }
    // Pedir Activate (algunas apps lo atienden) y dejar que el script complete:
    // enfocar la ventana si apareció/existe, o relanzar la app si no hay ninguna.
    function activate(i) {
        if (!i.onlyMenu) i.activate()
        const e = entryOf(i)
        Quickshell.execDetached([Qt.resolvedUrl("../scripts/tray-open.py").toString().replace("file://", ""), i.id, e ? e.id : ""])
        CharacterBus.islandCommand("close")
    }

    component Title: Text {
        color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold
        leftPadding: 4
    }

    Column {
        id: col
        x: 16; y: 16; width: parent.width - 32
        spacing: 8

        Item {
            width: parent.width; height: 76
            Character {
                id: chr
                size: 60
                anchors.centerIn: parent
                active: root.open && DisplayState.characterAnimated
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: m => chr.clicked((m.x - width / 2) / (width / 2)) }
            }
        }

        Title { text: I18n.tr("En segundo plano") }
        Rectangle {
            width: parent.width; radius: 18; color: Theme.surface; border.width: 1; border.color: Theme.track
            height: (root.items.length === 0 ? empty.height : list.implicitHeight) + 8
            Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            clip: true
            Text {
                id: empty
                visible: root.items.length === 0
                y: 4; width: parent.width; height: 44
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: I18n.tr("No hay apps en segundo plano"); color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 13
            }
            Column {
                id: list
                y: 4; width: parent.width
                Repeater {
                    model: root.items
                    delegate: Item {
                        id: row
                        required property var modelData
                        readonly property bool menuOpen: root.menuFor === modelData
                        width: list.width; height: 40 + menuBox.height
                        Rectangle {
                            x: 6; y: 2; width: parent.width - 12; height: 36; radius: 18
                            color: ma.containsMouse || row.menuOpen ? Theme.hover : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        Image {
                            x: 16; y: 10; width: 20; height: 20
                            property bool failed: false
                            source: failed ? root.entryIcon(row.modelData) : root.iconOf(row.modelData)
                            onStatusChanged: if (status === Image.Error && !failed) failed = true
                            sourceSize: Qt.size(40, 40); asynchronous: true
                        }
                        Text {
                            x: 46; y: 0; height: 40; width: parent.width - 60; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                            text: root.nameOf(row.modelData)
                            color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13
                        }
                        MouseArea {
                            id: ma
                            width: parent.width; height: 40
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: m => {
                                if (m.button === Qt.RightButton) root.menuFor = row.menuOpen ? null : row.modelData
                                else { root.menuFor = null; root.activate(row.modelData) }
                            }
                        }

                        // Menú de la app, desplegado bajo la fila.
                        Rectangle {
                            id: menuBox
                            x: 12; y: 40; width: parent.width - 24; radius: 16
                            color: Theme.field
                            height: row.menuOpen ? menuCol.implicitHeight + 8 : 0
                            opacity: row.menuOpen ? 1 : 0
                            visible: height > 0
                            clip: true
                            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 160 } }
                            QsMenuOpener { id: opener; menu: row.menuOpen && row.modelData.hasMenu ? row.modelData.menu : null }
                            Column {
                                id: menuCol
                                y: 4; width: parent.width
                                Repeater {
                                    model: opener.children
                                    delegate: Column {
                                        id: top
                                        required property var modelData
                                        width: menuCol.width
                                        TrayMenuRow { id: topRow; entry: top.modelData; onToggle: expanded = !expanded; onActivated: root.trigger(top.modelData) }
                                        // Submenú en línea (un nivel), con sangría.
                                        Column {
                                            x: 12; width: parent.width - 12
                                            visible: topRow.expanded
                                            QsMenuOpener { id: sub; menu: topRow.expanded ? top.modelData : null }
                                            Repeater {
                                                model: sub.children
                                                delegate: TrayMenuRow { required property var modelData; entry: modelData; onActivated: root.trigger(modelData) }
                                            }
                                        }
                                    }
                                }
                                // Sin menú propio: cerrar la app con amabilidad (SIGTERM).
                                Item {
                                    visible: !row.modelData.hasMenu
                                    width: parent.width; height: visible ? 32 : 0
                                    Rectangle {
                                        x: 4; width: parent.width - 8; height: 28; radius: 14; anchors.verticalCenter: parent.verticalCenter
                                        color: qMa.containsMouse ? Theme.hover : "transparent"
                                    }
                                    Text {
                                        x: 16; anchors.verticalCenter: parent.verticalCenter
                                        text: I18n.tr("Cerrar"); color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13
                                    }
                                    MouseArea { id: qMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.quit(row.modelData) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
