// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell
import Quickshell.Io
import "../Common"
import "../Character"

// Acerca de Minimo OS: personaje, versión, descripción, autoría y licencia.
Column {
    id: root
    spacing: 18
    property bool shown: false
    property string version: ""
    property string hyprVersion: ""
    property string qsVersion: ""

    // Al mostrar la página, el personaje saluda.
    // Las versiones se consultan una sola vez (no en cada apertura).
    onShownChanged: if (shown) { greetLater.restart(); if (!root.hyprVersion) hv.running = true; if (!root.qsVersion) qv.running = true }
    Timer { id: greetLater; interval: 350; onTriggered: chr.react("greet") }

    FileView {
        path: Qt.resolvedUrl("../VERSION").toString().replace("file://", "")
        onLoaded: root.version = text().trim()
    }
    Process {
        id: hv
        command: ["hyprctl", "version"]
        stdout: StdioCollector { onStreamFinished: { const m = text.match(/Hyprland\s+([\d.]+)/); root.hyprVersion = m ? m[1] : "" } }
    }
    Process {
        id: qv
        command: ["qs", "--version"]
        stdout: StdioCollector { onStreamFinished: { const m = text.match(/Quickshell\s+([\d.]+)/); root.qsVersion = m ? m[1] : "" } }
    }

    Item { width: 1; height: 8 }
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 96; height: 104
        Character { id: chr; size: 88; anchors.centerIn: parent; active: root.shown && DisplayState.characterAnimated
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: m => chr.clicked((m.x - width / 2) / (width / 2)) } }
    }
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Minimo OS"; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 28; font.weight: Font.Bold }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.version ? I18n.tr("Versión %1", root.version) : ""; color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 13 }
    }
    Text {
        width: Math.min(parent.width, 440)
        anchors.horizontalCenter: parent.horizontalCenter
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        lineHeight: 1.25
        text: I18n.tr("Minimo OS es una configuración minimalista de Hyprland: una isla flotante y un personaje feliz. Nada más de lo necesario.")
        color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 14
    }
    PillButton {
        anchors.horizontalCenter: parent.horizontalCenter
        icon: "external"; text: I18n.tr("Ver en GitHub")
        onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/Diegolede/minimo-os"])
    }

    Rectangle {
        width: parent.width
        height: info.implicitHeight + 8
        radius: 20
        color: Theme.surface
        Column {
            id: info
            width: parent.width
            y: 4
            Repeater {
                model: [
                    { k: I18n.tr("Creado por"), v: "TRN1 (Diego Ledesma)" },
                    { k: "Hyprland", v: root.hyprVersion || "—" },
                    { k: "Quickshell", v: root.qsVersion || "—" },
                    { k: I18n.tr("Licencia"), v: "MIT" }
                ]
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: info.width; height: 44
                    Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: modelData.k; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13 }
                    Text { anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter; text: modelData.v; color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 13 }
                    Rectangle { visible: index > 0; x: 18; width: parent.width - 36; height: 1; color: Theme.track }
                }
            }
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: I18n.tr("© 2026 Diego Ledesma (TRN1). Licencia MIT.")
        color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 11
    }
}
