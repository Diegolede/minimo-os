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
    // Con una captura recién tomada la isla crece hacia abajo con una vista previa grande
    // (la píldora anima ancho/alto con su Behavior; la fila de arriba queda igual).
    readonly property bool hasShot: shot.ready && root.notif !== null && Recorder.notice === ""
    implicitWidth: Math.max(row.implicitWidth, hasShot ? shot.boxW + 2 * shot.side - Theme.compactPadX * 2 : 0)
    implicitHeight: Theme.compactH + (hasShot ? shot.boxH + shot.side : 0)

    // Notificación en curso (la isla la muestra junto al personaje, sin taparlo).
    readonly property var notif: Notifs.current   // cola en Common/Notifs.qml
    readonly property bool notifQuiet: notif !== null && Notifs.fromFocused(notif)
    SystemClock { id: clock; precision: SystemClock.Minutes }

    Row {
        id: row
        anchors.horizontalCenter: parent.horizontalCenter
        y: (Theme.compactH - height) / 2
        spacing: 10
        Character {
            id: chr; size: 22; active: root.active && DisplayState.characterAnimated; anchors.verticalCenter: parent.verticalCenter
            mood: Laptop.critical ? "worried" : ""      // batería crítica: preocupado (solo ojos)
        }
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
        // Batería (solo si hay una): barrita con el nivel; roja solo en crítica. Al enchufar,
        // el relleno late unos segundos (animación de carga).
        Row {
            id: batInd
            visible: Laptop.present && !root.notif && Recorder.notice === ""
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 22; height: 10; radius: 5; color: Theme.track; clip: true
                Rectangle {
                    id: batFill
                    height: parent.height; radius: 5
                    width: Math.max(height, parent.width * (Laptop.present ? Laptop.bat.pct / 100 : 0))
                    color: Laptop.critical ? Theme.danger : Theme.fill
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    SequentialAnimation on opacity {
                        id: chargePulse
                        running: false
                        loops: 3
                        NumberAnimation { to: 0.3; duration: 450; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 450; easing.type: Easing.InOutSine }
                    }
                }
                Connections { target: Laptop; function onChargedAtChanged() { if (root.active) chargePulse.restart() } }
            }
            Text {
                enabled: false
                anchors.verticalCenter: parent.verticalCenter
                text: Laptop.present ? Laptop.bat.pct + "%" : ""
                color: Laptop.critical ? Theme.danger : Theme.textSecondary
                font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium; font.features: { "tnum": 1 }
            }
        }
        // OSD de volumen/brillo: barrita fina con el nivel, junto al texto del aviso.
        Rectangle {
            visible: Laptop.notice !== "" && Laptop.level >= 0 && Recorder.notice === "" && !root.notif
            anchors.verticalCenter: parent.verticalCenter
            width: 64; height: 6; radius: 3; color: Theme.track
            Rectangle {
                height: parent.height; radius: 3; color: Theme.fill
                width: Math.max(height, parent.width * Math.max(0, Laptop.level))
                Behavior on width { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
            }
        }
        // Aviso de batería / brillo / tapa (crítica en rojo).
        Text {
            enabled: false
            visible: Laptop.notice !== "" && Recorder.notice === "" && !root.notif
            anchors.verticalCenter: parent.verticalCenter
            text: Laptop.notice
            color: Laptop.noticeKind === "critical" ? Theme.danger : Laptop.noticeKind === "low" ? Theme.textPrimary : Theme.textSecondary
            font.family: Theme.font; font.pixelSize: 12
            font.weight: Laptop.noticeKind === "critical" || Laptop.noticeKind === "low" ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 260)
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
                    color: am.containsMouse ? Theme.hover : Theme.surface
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text { id: at; anchors.centerIn: parent; text: modelData.text; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium }
                    MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.invoke(modelData) }
                }
            }
        }
        // Más avisos en cola: "+2" discreto (se ven de a uno, así sabés que hay más).
        Text {
            enabled: false
            visible: root.notif !== null && Recorder.notice === "" && Notifs.queue.length > 1
            anchors.verticalCenter: parent.verticalCenter
            text: "+" + (Notifs.queue.length - 1)
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12; font.features: { "tnum": 1 }
        }
        // No molestar activo: luna chica (sabés por qué no llegan avisos).
        Icon {
            visible: Notifs.dnd && !root.notif && Recorder.notice === "" && Laptop.notice === ""
            anchors.verticalCenter: parent.verticalCenter
            name: "moon"; size: 14; tone: "gray"
        }
        Rectangle {
            visible: SysStatus.known && !SysStatus.online
            anchors.verticalCenter: parent.verticalCenter
            width: 7; height: 7; radius: 3.5
            color: Theme.recording
        }
        WorkspaceDots { anchors.verticalCenter: parent.verticalCenter }
    }

    // Vista previa de la captura: ancho 440 px (alto según la proporción, máx. 300 px).
    // Se decodifica escalada (sourceSize) y se descarga al irse el aviso (source = "").
    Item {
        id: shot
        readonly property string src: Notifs.thumbOf(root.notif)
        readonly property bool ready: src !== "" && img.status === Image.Ready && img.implicitWidth > 0
        readonly property real aspect: ready ? img.implicitWidth / img.implicitHeight : 16 / 9
        readonly property int side: 10                       // margen inferior y lateral
        readonly property real boxW: Math.round(Math.min(440, 300 * aspect))
        readonly property real boxH: Math.round(boxW / aspect)
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.compactH
        width: boxW; height: boxH
        opacity: root.hasShot ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }
        ClippingRectangle {
            anchors.fill: parent
            radius: Theme.radiusCard - shot.side             // concéntrico con la isla
            color: Theme.field
            Image {
                id: img
                anchors.fill: parent
                source: shot.src
                sourceSize.width: 880                        // 2× para pantallas HiDPI, nunca la captura entera
                fillMode: Image.PreserveAspectFit
                asynchronous: true; cache: false; smooth: true; mipmap: false
            }
        }
    }

    // Zzz al dormir (flotan desde el personaje).
    Zzz {
        x: row.x + chr.x + chr.width - 1
        y: row.y + chr.y - 14
        running: chr.asleep && root.active
        frozen: IdleState.unattended
    }
}
