// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import "../../Common"

// Wi-Fi: fila con red actual, señal e interruptor; al tocarla se despliegan las redes
// cercanas. Vive en el panel de estado (Internet); visible si hay placa Wi-Fi.
Column {
    id: root
    property bool active: false            // menú abierto: consultar NetworkManager
    property bool expanded: false
    property string askFor: ""             // SSID que pide contraseña
    property int radius: 18                // igual que las tarjetas del panel de estado
    spacing: 6
    visible: Network.hasNmcli && Network.hasWifi
    onActiveChanged: { active ? Network.acquire() : Network.release(); if (!active) { expanded = false; askFor = ""; Network.error = "" } }
    Component.onDestruction: if (active) Network.release()

    // Fila principal.
    Rectangle {
        width: parent.width; height: 52; radius: root.radius
        color: rowMouse.containsMouse ? Theme.hover : Theme.surface; border.width: 1; border.color: Theme.track
        Behavior on color { ColorAnimation { duration: 140 } }
        Rectangle {
            id: badge
            x: 8; anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36; radius: 18
            color: Network.wifiEnabled ? Theme.fill : Theme.field
            Icon { anchors.centerIn: parent; name: "wifi"; size: 18; tone: Network.wifiEnabled ? "white" : "gray" }
        }
        Column {
            anchors.left: badge.right; anchors.leftMargin: 12
            anchors.right: sw.left; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            Text { width: parent.width; elide: Text.ElideRight; text: "Wi-Fi"; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold }
            Text {
                width: parent.width; elide: Text.ElideRight
                text: !Network.wifiEnabled ? "Desactivado"
                    : Network.connecting ? "Conectando a " + Network.connecting + "…"
                    : Network.ssid || "Sin conexión"
                color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12
            }
        }
        MouseArea {
            id: rowMouse
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: { root.expanded = !root.expanded; if (root.expanded) Network.scan() }
        }
        SignalBars { anchors.right: sw.left; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; signal: Network.signal; visible: Network.ssid !== "" && Network.wifiEnabled }
        MSwitch { id: sw; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; checked: Network.wifiEnabled; onToggled: v => Network.setEnabled(v) }
    }

    // Lista de redes.
    Rectangle {
        width: parent.width
        visible: root.expanded && Network.wifiEnabled
        height: visible ? Math.min(listCol.implicitHeight + 12, 300) : 0
        radius: root.radius
        color: Theme.surface; border.width: 1; border.color: Theme.surfaceBorder
        clip: true
        Flickable {
            anchors.fill: parent; anchors.margins: 6
            contentHeight: listCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: listCol
                width: parent.width
                Text {
                    visible: Network.networks.length === 0
                    x: 12; height: 36; verticalAlignment: Text.AlignVCenter
                    text: "Buscando redes…"; color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12
                }
                Repeater {
                    model: Network.networks.slice(0, 12)
                    delegate: Column {
                        id: net
                        required property var modelData
                        width: listCol.width
                        Rectangle {
                            width: parent.width; height: 38; radius: 12
                            color: nm.containsMouse ? Theme.hover : "transparent"
                            Text {
                                x: 14; anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 100; elide: Text.ElideRight
                                text: net.modelData.ssid
                                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13
                                font.weight: net.modelData.active ? Font.DemiBold : Font.Normal
                            }
                            Row {
                                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                                spacing: 8
                                Icon { name: "check"; size: 14; visible: net.modelData.active; anchors.verticalCenter: parent.verticalCenter }
                                Icon { name: "lock"; size: 13; tone: "gray"; visible: net.modelData.secure; anchors.verticalCenter: parent.verticalCenter }
                                SignalBars { signal: net.modelData.signal; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea {
                                id: nm
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const n = net.modelData
                                    if (n.active) { Network.disconnect(); return }
                                    if (n.secure && !n.known) { root.askFor = root.askFor === n.ssid ? "" : n.ssid; pass.text = ""; Qt.callLater(() => pass.forceActiveFocus()) }
                                    else { root.askFor = ""; Network.connect(n.ssid, "") }
                                }
                            }
                        }
                        // Contraseña (solo para la red elegida).
                        Rectangle {
                            visible: root.askFor === net.modelData.ssid
                            width: parent.width; height: visible ? 40 : 0; radius: 20
                            color: Theme.field
                            border.width: 1; border.color: Theme.track
                            TextInput {
                                id: pass
                                onTextChanged: if (activeFocus) CharacterBus.typed()
                                onActiveFocusChanged: if (!activeFocus) CharacterBus.typingStopped()
                                anchors.left: parent.left; anchors.leftMargin: 14
                                anchors.right: go.left; anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                echoMode: TextInput.Password
                                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13
                                clip: true
                                cursorDelegate: Rectangle { width: 2; radius: 1; color: Theme.textPrimary; visible: pass.activeFocus }
                                Text { visible: !pass.text; text: "Contraseña"; color: Theme.textSecondary; font: pass.font }
                                onAccepted: go.submit()
                            }
                            Rectangle {
                                id: go
                                function submit() { if (pass.text.length > 0) { Network.connect(net.modelData.ssid, pass.text); pass.text = ""; root.askFor = "" } }
                                anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
                                width: 76; height: 32; radius: 16
                                color: pass.text.length > 0 ? Theme.fill : Theme.track
                                Text { anchors.centerIn: parent; text: "Unirse"; color: pass.text.length > 0 ? Theme.onAccent : Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: go.submit() }
                            }
                        }
                    }
                }
            }
        }
    }
    Text {
        visible: Network.error !== "" && root.expanded
        x: 14
        text: Network.error
        color: Theme.danger; font.family: Theme.font; font.pixelSize: 12
    }
}
