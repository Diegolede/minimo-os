// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../Common"

// Lanzador estilo Spotlight (Super+B): tarjeta blanca centrada, buscador grande,
// resultados con iconos, navegación con teclado. Clic afuera o Escape cierra.
PanelWindow {
    id: win
    readonly property bool open: LauncherState.open
    property real t: open ? 1 : 0          // progreso de la animación
    Behavior on t { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }

    visible: open || t > 0.01
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "minimo-launcher"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property var results: Apps.search(field.text, 7)
    property int selected: 0
    onResultsChanged: selected = 0

    onOpenChanged: {
        if (open) { field.text = ""; focusLater.restart() }
    }
    Timer { id: focusLater; interval: 60; onTriggered: field.forceActiveFocus() }

    function launch(entry) {
        if (!entry) return
        entry.execute()
        LauncherState.hide()
    }

    // Velo muy sutil + clic afuera cierra.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.08 * win.t)
        MouseArea { anchors.fill: parent; onPressed: LauncherState.hide() }
    }

    Rectangle {
        id: shadowSrc
        x: card.x; y: card.y; width: card.width; height: card.height
        radius: card.radius; color: Theme.card
        opacity: win.t; scale: card.scale
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: Theme.shadow
            shadowBlur: 1.0; blurMax: 48; shadowVerticalOffset: 12; autoPaddingEnabled: true
        }
    }

    Rectangle {
        id: card
        width: 600
        height: col.implicitHeight + 20
        x: (win.width - width) / 2
        y: win.height * 0.22
        radius: Math.min(height / 2, 32)
        color: Theme.card
        opacity: win.t
        scale: 0.96 + 0.04 * win.t
        clip: true
        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent }   // no cerrar al hacer clic dentro

        Column {
            id: col
            x: 10; y: 10
            width: parent.width - 20
            spacing: 4

            Rectangle {
                width: parent.width; height: 56
                radius: height / 2
                color: Theme.field
                Icon { id: lupa; x: 20; anchors.verticalCenter: parent.verticalCenter; name: "search"; tone: "gray"; size: 22 }
                TextInput {
                    id: field
                    onTextChanged: if (activeFocus) CharacterBus.typed()
                    onActiveFocusChanged: if (!activeFocus) CharacterBus.typingStopped()
                    anchors.left: lupa.right; anchors.leftMargin: 12
                    anchors.right: parent.right; anchors.rightMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.textPrimary
                    font.family: Theme.font; font.pixelSize: 21
                    selectionColor: Theme.track; selectedTextColor: Theme.textPrimary
                    cursorDelegate: Rectangle { width: 2; radius: 1; color: Theme.textPrimary; visible: field.activeFocus }
                    clip: true
                    Text { visible: !field.text; text: I18n.tr("Buscar aplicaciones"); color: Theme.textSecondary; font: field.font }
                    Keys.onEscapePressed: LauncherState.hide()
                    Keys.onDownPressed: win.selected = Math.min(win.selected + 1, win.results.length - 1)
                    Keys.onUpPressed: win.selected = Math.max(win.selected - 1, 0)
                    Keys.onTabPressed: win.selected = (win.selected + 1) % Math.max(1, win.results.length)
                    // Shift+Tab: hacia atrás (antes no hacía nada)
                    Keys.onBacktabPressed: win.selected = (win.selected - 1 + Math.max(1, win.results.length)) % Math.max(1, win.results.length)
                    onAccepted: if (win.results.length > 0) win.launch(win.results[win.selected])
                }
            }

            Item { width: 1; height: 4; visible: win.results.length > 0 }
            // Sin resultados: lo dice en vez de quedar en blanco.
            Text {
                visible: field.text.trim() !== "" && win.results.length === 0
                width: parent.width; height: 44
                verticalAlignment: Text.AlignVCenter; leftPadding: 20
                elide: Text.ElideRight
                text: I18n.tr("Sin resultados para «%1»", field.text.trim())
                color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 14
            }

            Repeater {
                model: win.results
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: col.width; height: 52; radius: height / 2
                    color: index === win.selected ? Theme.field : (rm.containsMouse ? Theme.subtle : "transparent")
                    // Icono dentro de un "squircle" gris claro.
                    Rectangle {
                        id: ic
                        x: 8; anchors.verticalCenter: parent.verticalCenter
                        width: 38; height: 38; radius: 12
                        color: index === win.selected ? Theme.raised : Theme.field
                        Image {
                            anchors.centerIn: parent
                            width: 26; height: 26; sourceSize: Qt.size(52, 52)
                            source: Apps.iconFor(modelData)
                        }
                    }
                    Column {
                        anchors.left: ic.right; anchors.leftMargin: 14
                        anchors.right: parent.right; anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        Text { width: parent.width; elide: Text.ElideRight; text: modelData.name; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 15 }
                        Text { width: parent.width; elide: Text.ElideRight; text: modelData.genericName || modelData.comment || ""; visible: text !== ""; color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12 }
                    }
                    MouseArea {
                        id: rm
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: win.launch(modelData)
                    }
                }
            }
        }
    }
}
