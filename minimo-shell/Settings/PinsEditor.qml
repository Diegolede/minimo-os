// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import "../Common"

// Menú de la isla: qué controles y botones aparecen fijados, más accesos propios
// (nombre + comando). Los botones ocupan filas de 4 y hay como máximo 3 filas.
Column {
    id: root
    spacing: 8

    readonly property var customs: DisplayState.customItems
    readonly property int used: QuickItems.pinnedButtons.length

    function add() {
        if (QuickItems.addCustom(nameIn.text, cmdIn.text)) { nameIn.text = ""; cmdIn.text = ""; nameIn.focus = false; cmdIn.focus = false }
    }

    Item {
        width: parent.width; height: title.implicitHeight
        SectionTitle { id: title; text: I18n.tr("Menú de la isla") }
        Text {
            anchors.right: parent.right; anchors.baseline: title.baseline
            text: I18n.tr("%1 de %2 botones", root.used, QuickItems.maxButtons) + (QuickItems.full ? I18n.tr(" · completo") : "")
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12
        }
    }

    Rectangle {
        width: parent.width; height: list.implicitHeight; radius: 20; color: Theme.surface; border.width: 1; border.color: Theme.track
        Column {
            id: list
            width: parent.width
            // Una sola lista en el orden del menú: catálogo y accesos propios mezclados.
            Repeater {
                model: QuickItems.order
                delegate: PinRow {
                    id: pr
                    required property string modelData
                    required property int index
                    readonly property var it: QuickItems.item(modelData)
                    readonly property bool isCustom: QuickItems.custom(modelData) !== null
                    width: list.width
                    icon: isCustom ? "" : (it?.icon ?? "")
                    text: it?.label ?? ""
                    detail: isCustom ? it.cmd : (it?.slider ? I18n.tr("Control deslizante") : "")
                    removable: isCustom
                    pinned: QuickItems.pinned(modelData)
                    canPin: QuickItems.canPin(modelData)
                    canUp: index > 0
                    canDown: index < QuickItems.order.length - 1
                    last: index === QuickItems.order.length - 1
                    onToggled: v => QuickItems.setPinned(modelData, v)
                    onMoveRequested: d => QuickItems.move(modelData, d)
                    onRemoveRequested: QuickItems.removeCustom(modelData)
                }
            }
        }
    }

    // Nuevo acceso propio.
    Row {
        width: parent.width
        spacing: 8
        topPadding: 4
        Rectangle {
            id: nameBox
            width: Math.round(Math.min(200, (root.width - addBtn.width - 16) * 0.38)); height: 36; radius: 18; color: Theme.field
            TextInput {
                id: nameIn
                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13
                clip: true; selectByMouse: true; maximumLength: 24
                KeyNavigation.tab: cmdIn
                onAccepted: cmdIn.forceActiveFocus()
            }
            Text { anchors.fill: nameIn; verticalAlignment: Text.AlignVCenter; visible: !nameIn.text; text: I18n.tr("Nombre"); color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 13 }
        }
        Rectangle {
            width: parent.width - nameBox.width - addBtn.width - 16; height: 36; radius: 18; color: Theme.field
            TextInput {
                id: cmdIn
                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13
                clip: true; selectByMouse: true
                onAccepted: root.add()
            }
            Text { anchors.fill: cmdIn; verticalAlignment: Text.AlignVCenter; visible: !cmdIn.text; text: I18n.tr("Comando (p. ej. firefox)"); color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 13 }
        }
        PillButton {
            id: addBtn
            icon: "plus"; text: I18n.tr("Agregar"); primary: nameIn.text.trim() !== "" && cmdIn.text.trim() !== ""
            onClicked: root.add()
        }
    }
    Text {
        width: parent.width
        wrapMode: Text.WordWrap
        topPadding: 2
        text: QuickItems.full ? I18n.tr("Con 3 filas llenas, desactivá un botón para fijar otro.") : I18n.tr("Los accesos propios ejecutan el comando con sh y se fijan al agregarlos.")
        color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12
    }
}
