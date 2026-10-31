// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../Common"

// Ventana de Ajustes estilo "Configuración del Sistema": tarjeta blanca centrada,
// barra lateral con secciones y contenido a la derecha. Escape o clic afuera cierra.
PanelWindow {
    id: win
    readonly property bool open: SettingsState.open
    property double lastSectionClick: 0
    function pickSection(id) {
        const now = Date.now()
        if (now - lastSectionClick < 180) return
        lastSectionClick = now
        SettingsState.section = id
    }
    property real t: open ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.durClose; easing.type: Easing.OutQuint } }

    visible: open || t > 0.01
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "minimo-settings"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: if (open) { card.forceActiveFocus(); personal.refresh(); display.refresh() }

    readonly property var sections: [
        { id: "personalizacion", label: I18n.tr("Personalización"), icon: "brush" },
        { id: "pantalla", label: I18n.tr("Pantalla"), icon: "display" },
        { id: "atajos", label: I18n.tr("Atajos"), icon: "keyboard" },
        { id: "gestos", label: I18n.tr("Gestos"), icon: "gesture" },
        { id: "actualizaciones", label: I18n.tr("Actualizaciones"), icon: "update" },
        { id: "minimo", label: "Minimo OS", icon: "info" }
    ]

    // Velo + clic afuera cierra.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.14 * win.t)
        MouseArea { anchors.fill: parent; onClicked: { if (display.pending !== null) return; SettingsState.hide() } }
    }

    Rectangle {
        x: card.x; y: card.y; width: card.width; height: card.height
        radius: card.radius; color: Theme.card
        opacity: win.t; scale: card.scale
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: Theme.shadow
            shadowBlur: 0.75; blurMax: 24; shadowVerticalOffset: 8; autoPaddingEnabled: true
        }
    }

    Rectangle {
        id: card
        width: Math.min(920, win.width - 80)
        height: Math.min(640, win.height - 80)
        anchors.centerIn: parent
        radius: Theme.radiusCard
        color: Theme.card
        opacity: win.t
        scale: 0.94 + 0.06 * win.t
        clip: true
        focus: true
        Keys.onEscapePressed: {
            if (display.pending !== null) { display.revert(); return }
            if (SettingsState.section === "pantalla" && display.anyListOpen) { display.closeLists(); return }
            SettingsState.hide()
        }

        MouseArea { anchors.fill: parent }   // no cerrar al hacer clic dentro

        // Barra lateral.
        Rectangle {
            id: sidebar
            width: Theme.sidebarW; height: parent.height
            color: Theme.subtle
            radius: card.radius           // esquinas izquierdas redondeadas como la tarjeta
            Rectangle { anchors.right: parent.right; width: parent.radius; height: parent.height; color: parent.color }
            Column {
                x: Theme.space3 + 2; y: Theme.space5 + 2
                width: parent.width - Theme.space6 - 4
                spacing: Theme.space1
                Text { x: 12; text: I18n.tr("Ajustes"); color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: Theme.fontTitle - 4; font.weight: Font.DemiBold; bottomPadding: Theme.space3 + 2 }
                Repeater {
                    model: win.sections
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool cur: SettingsState.section === modelData.id
                        width: parent.width; height: Theme.hitMin - 2; radius: (Theme.hitMin - 2) / 2
                        color: cur ? Theme.fill : (sbm.containsMouse ? Theme.hover : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.durMicro } }
                        activeFocusOnTab: true
                        Keys.onReturnPressed: win.pickSection(modelData.id)
                        Keys.onSpacePressed: win.pickSection(modelData.id)
                        Rectangle { anchors.fill: parent; anchors.margins: -2; radius: parent.radius; color: "transparent"; border.width: 2; border.color: Theme.fill; visible: parent.activeFocus }
                        Row {
                            x: Theme.space3 + 2; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.space3
                            Icon { name: modelData.icon; size: Theme.iconSm + 4; tone: cur ? "white" : "dark"; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: modelData.label; color: cur ? Theme.onAccent : Theme.textPrimary; font.family: Theme.font; font.pixelSize: Theme.fontBody; font.weight: cur ? Font.DemiBold : Font.Normal; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { id: sbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.pickSection(modelData.id) }
                    }
                }
            }
        }

        // Contenido.
        Item {
            id: content
            anchors.left: sidebar.right; anchors.right: parent.right
            anchors.top: parent.top; anchors.bottom: parent.bottom

            Text {
                id: heading
                x: Theme.space6 + Theme.space3; y: Theme.space6 + 2
                text: SettingsState.section === "pantalla" ? I18n.tr("Pantalla") : SettingsState.section === "atajos" ? I18n.tr("Atajos de teclado") : SettingsState.section === "gestos" ? I18n.tr("Gestos de la isla dinámica") : SettingsState.section === "actualizaciones" ? I18n.tr("Actualizaciones") : SettingsState.section === "minimo" ? I18n.tr("Acerca de") : I18n.tr("Personalización")
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: Theme.fontTitle - 4; font.weight: Font.DemiBold
            }
            Flickable {
                id: flick
                anchors.top: heading.bottom; anchors.topMargin: 18
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                anchors.leftMargin: Theme.space6 + Theme.space3; anchors.rightMargin: Theme.space6 + Theme.space3
                contentHeight: (SettingsState.section === "pantalla" ? display.implicitHeight : SettingsState.section === "atajos" ? (shortcuts.item ? shortcuts.item.implicitHeight : 0) : SettingsState.section === "gestos" ? (gestures.item ? gestures.item.implicitHeight : 0) : SettingsState.section === "actualizaciones" ? (updates.item ? updates.item.implicitHeight : 0) : SettingsState.section === "minimo" ? (about.item ? about.item.implicitHeight : 0) : personal.implicitHeight) + Theme.space8
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                // Conserva el scroll por sección al volver; refresca pantallas al mostrarlas.
                property var scrollMem: ({})
                Connections {
                    target: SettingsState
                    function onSectionChanged() {
                        const prev = SettingsState.section  // ya cambió; guardamos al salir vía Binding abajo
                        flick.contentY = flick.scrollMem[SettingsState.section] || 0
                        if (SettingsState.section === "pantalla") display.refresh()
                        if (SettingsState.section === "personalizacion") personal.refresh()
                        if (SettingsState.section === "pantalla") display.closeLists()
                    }
                }
                onContentYChanged: if (win.open) flick.scrollMem[SettingsState.section] = flick.contentY

                // Personalización y Pantalla siempre montadas (diálogos / refresh al abrir).
                PersonalizationPage {
                    id: personal
                    width: flick.width
                    visible: SettingsState.section === "personalizacion"
                    onPickerOpened: SettingsState.hide()
                }
                DisplayPage {
                    id: display
                    width: flick.width
                    visible: SettingsState.section === "pantalla"
                }
                // Páginas secundarias: Loader (RAM) — se montan al visitar la sección.
                Loader {
                    id: about
                    width: flick.width
                    active: win.open && SettingsState.section === "minimo"
                    visible: active
                    sourceComponent: AboutPage {
                        width: about.width
                        shown: about.active && win.open
                    }
                }
                Loader {
                    id: shortcuts
                    width: flick.width
                    active: win.open && SettingsState.section === "atajos"
                    visible: active
                    sourceComponent: ShortcutsPage {
                        width: shortcuts.width
                        shown: shortcuts.active && win.open
                    }
                }
                Loader {
                    id: updates
                    width: flick.width
                    active: win.open && SettingsState.section === "actualizaciones"
                    visible: active
                    sourceComponent: UpdatesPage {
                        width: updates.width
                        shown: updates.active && win.open
                    }
                }
                Loader {
                    id: gestures
                    width: flick.width
                    active: win.open && SettingsState.section === "gestos"
                    visible: active
                    sourceComponent: GesturesPage { width: gestures.width }
                }
            }
        }

        // Confirmación de cambio de pantalla (estilo macOS).
        Rectangle {
            anchors.fill: parent
            color: Theme.scrim
            visible: display.pending !== null
            MouseArea { anchors.fill: parent }
            Rectangle {
                anchors.centerIn: parent
                width: 380; height: cc.implicitHeight + Theme.space8 + Theme.space4; radius: Theme.radiusCard
                color: Theme.cardSolid
                border.width: 1; border.color: Theme.track
                Column {
                    id: cc
                    anchors.centerIn: parent
                    width: parent.width - Theme.space8 - Theme.space4
                    spacing: Theme.space3 - 2
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "display"; size: Theme.iconLg + 2 }
                    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: I18n.tr("¿Mantener esta configuración?"); color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: Theme.fontHeading; font.weight: Font.DemiBold; wrapMode: Text.WordWrap }
                    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: I18n.tr("Se revierte en %1 s", display.countdown); color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: Theme.fontLabel; font.features: { "tnum": 1 } }
                    Item { width: 1; height: Theme.space2 - 2 }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.space3 - 2
                        PillButton { text: I18n.tr("Revertir"); outlined: true; onClicked: display.revert() }
                        PillButton { text: I18n.tr("Mantener"); primary: true; onClicked: display.keep() }
                    }
                }
            }
        }
    }
}
