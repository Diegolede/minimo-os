// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import QtQuick.Shapes
import "../Common"

// Ilustración estática de un gesto de la isla (QtQuick.Shapes, sin animaciones ni timers):
// la isla compacta en negro y flechas/trazos que muestran la dirección.
Item {
    id: art
    property string kind: "tap"     // tap | right | swipeR | swipeL | swipeD | close | wheel | esc
    width: 140; height: 92
    readonly property color ink: Theme.textPrimary
    readonly property real cx: width / 2
    readonly property bool cardShape: kind === "close"
    readonly property bool toast: kind === "right"

    // Isla compacta (o expandida para "cerrar"): negro con los ojos de Minimo.
    Rectangle {
        id: pill
        x: art.cx - width / 2; y: art.cardShape ? 8 : 14
        width: art.cardShape ? 76 : art.toast ? 92 : 64
        height: art.cardShape ? 50 : 24
        radius: art.cardShape ? 14 : height / 2
        color: Theme.fill
        Row {
            x: art.cardShape ? 10 : 8; y: art.cardShape ? 8 : 6; spacing: 3
            Repeater { model: 2; Rectangle { width: 3.5; height: 9; radius: 1.75; color: Theme.onAccent } }
        }
        // Aviso: una línea de texto dentro de la isla.
        Rectangle { visible: art.toast; x: 24; y: 10; width: 46; height: 4; radius: 2; color: Theme.onAccent; opacity: 0.85 }
        // Panel abierto: renglones.
        Repeater {
            model: art.cardShape ? 3 : 0
            Rectangle { required property int index; x: 10; y: 24 + index * 8; width: 56 - index * 12; height: 3; radius: 1.5; color: Theme.onAccent; opacity: 0.85 }
        }
    }

    // Flecha genérica: trazo + punta (dos segmentos), extremos redondeados.
    component Arrow: Shape {
        id: ar
        property real x1; property real y1; property real x2; property real y2
        property bool both: false
        readonly property real ang: Math.atan2(y2 - y1, x2 - x1)
        readonly property real hl: 7
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: art.ink; strokeWidth: 2.4; fillColor: "transparent"
            capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
            startX: ar.x1; startY: ar.y1
            PathLine { x: ar.x2; y: ar.y2 }
            PathMove { x: ar.x2 - ar.hl * Math.cos(ar.ang - 0.6); y: ar.y2 - ar.hl * Math.sin(ar.ang - 0.6) }
            PathLine { x: ar.x2; y: ar.y2 }
            PathLine { x: ar.x2 - ar.hl * Math.cos(ar.ang + 0.6); y: ar.y2 - ar.hl * Math.sin(ar.ang + 0.6) }
            PathMove { x: ar.both ? ar.x1 + ar.hl * Math.cos(ar.ang - 0.6) : ar.x1; y: ar.both ? ar.y1 + ar.hl * Math.sin(ar.ang - 0.6) : ar.y1 }
            PathLine { x: ar.x1; y: ar.y1 }
            PathLine { x: ar.both ? ar.x1 + ar.hl * Math.cos(ar.ang + 0.6) : ar.x1; y: ar.both ? ar.y1 + ar.hl * Math.sin(ar.ang + 0.6) : ar.y1 }
        }
    }
    // Punto de toque: anillo + punto (clic).
    component Tap: Item {
        id: tp
        property bool secondary: false
        width: 26; height: 26
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: art.ink; strokeWidth: 2; fillColor: "transparent"
                PathAngleArc { centerX: 13; centerY: 13; radiusX: 11; radiusY: 11; startAngle: 0; sweepAngle: 360 }
            }
        }
        Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: art.ink }
    }

    Tap { visible: art.kind === "tap"; x: art.cx + 6; y: 46 }

    // Clic derecho sobre un aviso: toque + "×" (se descarta).
    Tap { visible: art.kind === "right"; x: art.cx - 30; y: 50 }
    Icon { visible: art.kind === "right"; x: art.cx + 10; y: 52; name: "dismiss"; size: 20; tone: "dark" }

    Arrow { visible: art.kind === "swipeR"; x1: art.cx - 34; y1: 62; x2: art.cx + 34; y2: 62 }
    Arrow { visible: art.kind === "swipeL"; x1: art.cx + 34; y1: 62; x2: art.cx - 34; y2: 62 }
    Arrow { visible: art.kind === "swipeD"; x1: art.cx; y1: 46; x2: art.cx; y2: 84 }
    Arrow { visible: art.kind === "close"; x1: art.cx - 38; y1: 76; x2: art.cx + 38; y2: 76; both: true }

    // Rueda: flecha doble vertical junto a la isla + puntos de escritorios.
    Arrow { visible: art.kind === "wheel"; x1: art.cx + 48; y1: 6; x2: art.cx + 48; y2: 46; both: true }
    Row {
        visible: art.kind === "wheel"
        x: art.cx - width / 2; y: 58; spacing: 6
        Repeater { model: 3; Rectangle { required property int index; width: index === 1 ? 16 : 7; height: 7; radius: 3.5; color: index === 1 ? art.ink : Theme.dot } }
    }

    // Escape: tecla.
    Rectangle {
        visible: art.kind === "esc"
        x: art.cx - width / 2; y: 50; width: 44; height: 28; radius: 8; color: Theme.fill
        Text { anchors.centerIn: parent; text: I18n.tr("Esc"); color: Theme.onAccent; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold }
    }
}
