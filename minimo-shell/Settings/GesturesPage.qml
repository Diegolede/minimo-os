// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import "../Common"

// Gestos de la isla dinámica: solo los que existen en Island/Island.qml (hoverZone) e
// IslandMenu. Ilustraciones estáticas (GestureArt, QtQuick.Shapes), sin timers.
Column {
    id: root
    spacing: Theme.space3 + 2

    readonly property var gestures: [
        { kind: "tap", title: I18n.tr("Clic"), detail: I18n.tr("Abre el menú de la isla. Si hay un aviso en pantalla, lo abre (la app, la captura o el panel correspondiente).") },
        { kind: "swipeR", title: I18n.tr("Deslizar hacia la derecha"), detail: I18n.tr("Muestra los recursos del sistema: internet, batería, CPU, memoria, disco y dispositivos.") },
        { kind: "swipeL", title: I18n.tr("Deslizar hacia la izquierda"), detail: I18n.tr("Muestra las apps en segundo plano (bandeja del sistema). Un clic las vuelve a abrir.") },
        { kind: "swipeD", title: I18n.tr("Deslizar hacia abajo"),
          detail: I18n.tr("Abre el menú de la isla, igual que un clic.") },
        { kind: "close", title: I18n.tr("Deslizar con un panel abierto"), detail: I18n.tr("Hacia la izquierda o la derecha, cierra el panel de recursos o de apps.") },
        { kind: "right", title: I18n.tr("Clic derecho en un aviso"), detail: I18n.tr("Descarta el aviso sin abrirlo.") },
        { kind: "wheel", title: I18n.tr("Rueda del mouse"), detail: I18n.tr("Sobre la isla compacta, pasa al escritorio anterior o siguiente.") },
        { kind: "esc", title: I18n.tr("Escape o clic afuera"), detail: I18n.tr("Cierra el menú o el panel abierto.") },
        { kind: "swipeL", title: I18n.tr("Tres dedos en el panel táctil"), detail: I18n.tr("Hacia la izquierda o la derecha, cambia de escritorio. Sin soltar, sigue pasando; un desliz corto se cancela.") },
        { kind: "tap", title: I18n.tr("Dos dedos en el panel táctil"), detail: I18n.tr("Un toque con dos dedos es clic derecho. Mientras escribís, la palma no mueve el puntero.") }
    ]

    Text {
        width: parent.width; wrapMode: Text.WordWrap
        text: I18n.tr("Para deslizar, arrastrá sobre la isla con el mouse o el panel táctil. Pasar el mouse por arriba la muestra y pausa los avisos.")
        color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: Theme.fontBody - 1
    }

    Flow {
        width: parent.width
        spacing: Theme.space3
        Repeater {
            model: root.gestures
            delegate: Rectangle {
                id: card
                required property var modelData
                width: (root.width - 12) / 2
                height: Math.max(col.implicitHeight + 28, 184)
                radius: Theme.radiusPill
                color: Theme.surface
                Column {
                    id: col
                    x: Theme.padSection; y: Theme.space3 + 2; width: parent.width - Theme.padSection * 2
                    spacing: Theme.space1 + 2
                    GestureArt { kind: card.modelData.kind; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { width: parent.width; wrapMode: Text.WordWrap; text: card.modelData.title; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold }
                    Text { width: parent.width; wrapMode: Text.WordWrap; text: card.modelData.detail; color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: Theme.fontCaption; lineHeight: Theme.lineCaption }
                }
            }
        }
    }
}
