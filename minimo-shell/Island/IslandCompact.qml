// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell.Widgets
import Quickshell
import "../Common"
import "../Character"

// Estado compacto: personaje + hora (HH:mm).
Item {
    id: root
    property alias character: chr
    property bool active: true
    implicitWidth: row.implicitWidth
    implicitHeight: Theme.compactH

    // Notificación en curso (la isla la muestra junto al personaje, sin taparlo).
    readonly property var notif: Notifs.current   // cola en Common/Notifs.qml
    readonly property bool notifQuiet: notif !== null && Notifs.fromFocused(notif)
    SystemClock { id: clock; precision: SystemClock.Minutes }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10
        Character { id: chr; size: 22; active: root.active && DisplayState.characterAnimated; anchors.verticalCenter: parent.verticalCenter }
        Text {
            visible: !root.notif
            enabled: false              // texto decorativo: sin interacción ni selección
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.textPrimary
            font.family: Theme.font
            font.pixelSize: 15
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
        }
        // Grabando: punto rojo que late + tiempo transcurrido.
        Row {
            visible: Recorder.recording && Recorder.notice === ""
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8; height: 8; radius: 4
                color: Theme.recording
                SequentialAnimation on opacity {
                    running: Recorder.recording && root.active
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }
            Text {
                enabled: false              // texto decorativo: sin interacción ni selección
                anchors.verticalCenter: parent.verticalCenter
                text: Recorder.elapsedText
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13
                font.features: { "tnum": 1 }
            }
        }
        // Mensaje breve (Guardado / Instalá wf-recorder).
        Text {
            enabled: false              // texto decorativo: sin interacción ni selección
            visible: Recorder.notice !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: Recorder.notice
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12
            elide: Text.ElideMiddle
            width: Math.min(implicitWidth, 230)
        }
        // Sin internet: punto rojo fijo (desliz sobre la isla para ver el detalle).
        Row {
            id: toast
            visible: root.notif !== null && Recorder.notice === ""
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            // Con miniatura (captura): imagen apaisada de esquinas redondeadas; si no, icono de la app.
            ClippingRectangle {
                id: thumbBox
                readonly property string thumb: Notifs.thumbOf(root.notif)
                visible: thumb !== "" && th.status === Image.Ready
                anchors.verticalCenter: parent.verticalCenter
                width: 40; height: 26; radius: 6
                color: Theme.field
                Image {
                    id: th
                    anchors.fill: parent
                    source: thumbBox.thumb
                    sourceSize: Qt.size(120, 78)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true; cache: false; smooth: true
                }
            }
            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18; sourceSize: Qt.size(36, 36)
                source: Notifs.thumbOf(root.notif) === "" ? Notifs.iconOf(root.notif) : ""
                visible: status === Image.Ready
                asynchronous: true; smooth: true
            }
            Text {
                enabled: false
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, root.notifQuiet ? 200 : 300)
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: !root.notif ? "" : (root.notif.summary || root.notif.appName)
                      + (!root.notifQuiet && root.notif.body ? "  ·  " + root.notif.body.replace(/\s+/g, " ") : "")
                color: root.notifQuiet ? Theme.textSecondary : Theme.textPrimary
                font.family: Theme.font; font.pixelSize: 13; font.weight: root.notifQuiet ? Font.Normal : Font.Medium
            }
            Repeater {
                // Hasta 2 acciones como píldoras (la "default" es el clic en el aviso).
                model: root.notif && !root.notifQuiet ? Array.from(root.notif.actions || []).filter(a => a.identifier !== "default").slice(0, 2) : []
                delegate: Rectangle {
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    width: at.implicitWidth + 20; height: 24; radius: 12
                    color: am.containsMouse ? Theme.hover : Theme.field
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text { id: at; anchors.centerIn: parent; text: modelData.text; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium }
                    MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.invoke(modelData) }
                }
            }
        }
        Rectangle {
            visible: SysStatus.known && !SysStatus.online
            anchors.verticalCenter: parent.verticalCenter
            width: 7; height: 7; radius: 3.5
            color: Theme.recording
        }
        WorkspaceDots { anchors.verticalCenter: parent.verticalCenter }
    }

    // Zzz al dormir (flotan desde el personaje).
    Zzz {
        x: row.x + chr.x + chr.width - 1
        y: row.y + chr.y - 14
        running: chr.asleep && root.active
        frozen: IdleState.unattended
    }
}
