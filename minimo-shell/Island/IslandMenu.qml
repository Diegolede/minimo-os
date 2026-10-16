// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell
import "../Common"
import "../Character"
import "sections"

// Menú de la isla expandida: compone las secciones con entrada escalonada.
Item {
    id: root
    signal done()
    property bool open: false
    readonly property bool searchFocused: search.hasFocus
    property alias character: chr
    property string page: "menu"   // "menu" | "desks" | "clip"
    implicitHeight: (page === "desks" ? desks.implicitHeight : page === "clip" ? clip.implicitHeight : col.implicitHeight) + 40

    function showClipboard() { clip.refresh(); page = "clip" }

    // El buscador no se enfoca solo: se activa al hacerle clic.
    function opened() { search.reset() }

    // Entrada escalonada: stage sube de a uno cada 45 ms al abrir.
    property int stage: 0
    Timer {
        id: stagger; interval: 45; repeat: true
        running: root.open && root.stage < 6
        onTriggered: root.stage++
    }
    onOpenChanged: if (!open) { stage = 0; page = "menu"; actions.reset() }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    component Reveal: Item {
        property int step: 0
        opacity: root.stage > step ? 1 : 0
        transform: Translate { y: root.stage > step ? 0 : 8; Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } } }
        Behavior on opacity { NumberAnimation { duration: 260 } }
    }

    Column {
        id: col
        x: root.page === "menu" ? 20 : -root.width * 0.3
        y: 20
        opacity: root.page === "menu" ? 1 : 0
        visible: opacity > 0
        enabled: root.page === "menu"
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        width: parent.width - 40
        spacing: 22

        Reveal {
            step: 0; width: parent.width; height: 48
            Row {
                spacing: 16
                Character {
                    id: chr; size: 44; active: root.open && DisplayState.characterAnimated; anchors.verticalCenter: parent.verticalCenter
                    // Clic en el personaje: guiño, risita… (4+ clics rápidos: caricias)
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: m => chr.clicked((m.x - width / 2) / (width / 2)) }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    Text {
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        color: Theme.textPrimary; font.family: Theme.font
                        font.pixelSize: 26; font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                    }
                    Text {
                        text: { const t = clock.date.toLocaleDateString(Qt.locale("es_AR"), "dddd d 'de' MMMM"); return t.charAt(0).toUpperCase() + t.slice(1) }
                        color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12
                    }
                }
            }
        }
        Reveal { step: 1; width: parent.width; height: search.implicitHeight
            SearchSection { id: search; width: parent.width; onLaunched: root.done() } }
        Reveal { step: 2; width: parent.width; height: media.implicitHeight; visible: media.player !== null
            MediaSection { id: media; width: parent.width } }
        // La visibilidad se decide con los datos, NO con `pinned.visible`: el `visible` de un hijo
        // es false mientras el menú está oculto, y atarlo al padre lo dejaba en false para siempre.
        Reveal { step: 3; width: parent.width; height: pinned.implicitHeight
            visible: QuickItems.pinnedSliders.length + QuickItems.pinnedButtons.length > 0
            PinnedSection { id: pinned; width: parent.width
                onDone: root.done(); onDesktops: { desks.refresh(); root.page = "desks" }
                onClipboard: root.showClipboard() } }
        Reveal { step: 4; width: parent.width; height: actions.implicitHeight
            ActionsSection { id: actions; anchors.horizontalCenter: parent.horizontalCenter; onDone: root.done()
                onSettings: { root.done(); SettingsState.show() } } }
    }

    WorkspacesView {
        id: desks
        x: root.page === "desks" ? 20 : root.width * 0.3
        y: 20
        width: root.width - 40
        opacity: root.page === "desks" ? 1 : 0
        visible: opacity > 0
        enabled: root.page === "desks"
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        onBack: root.page = "menu"
        onPicked: root.done()
    }

    ClipboardView {
        id: clip
        x: root.page === "clip" ? 20 : root.width * 0.3
        y: 20
        width: root.width - 40
        opacity: root.page === "clip" ? 1 : 0
        visible: opacity > 0
        enabled: root.page === "clip"
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        onBack: root.page = "menu"
        onPicked: root.done()
    }
}
