// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell
import Quickshell.Io
import "../Common"

// Pantalla: monitores (resolución/frecuencia y escala) + brillo y saturación.
// Los cambios se aplican con la API Lua de Hyprland (hyprctl eval 'hl.monitor{…}')
// y piden confirmación; si no se confirma en 15 s se revierte. Al confirmar se
// guardan en ~/.config/hypr/minimo/monitores.lua (con respaldo previo).
Column {
    id: root
    spacing: 20

    property var monitors: []
    property var pending: null          // { name, prev:{mode,scale,pos}, next:{…} }
    property int countdown: 0
    readonly property var scales: [1, 1.25, 1.5, 2]
    readonly property string outputsFile: Quickshell.env("HOME") + "/.config/hypr/minimo/monitores.lua"

    function refresh() { query.running = false; query.running = true }
    Component.onCompleted: refresh()

    Process {
        id: query
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.monitors = JSON.parse(text).filter(m => !m.disabled) } catch (e) { root.monitors = [] } }
        }
    }

    function modeOf(m) { return m.width + "x" + m.height + "@" + m.refreshRate.toFixed(2) }
    function posOf(m) { return m.x + "x" + m.y }
    function rule(name, cfg) {
        return 'hl.monitor({ output = "' + name + '", mode = "' + cfg.mode + '", position = "' + cfg.pos + '", scale = ' + cfg.scale + ' })'
    }
    function applyCfg(name, cfg) {
        Quickshell.execDetached(["hyprctl", "eval", rule(name, cfg)])
        refreshLater.restart()
    }
    Timer { id: refreshLater; interval: 400; onTriggered: root.refresh() }

    // Pide un cambio: aplica y arranca la cuenta regresiva.
    function request(m, mode, scale) {
        const prev = { mode: modeOf(m), scale: m.scale, pos: posOf(m) }
        const next = { mode: mode, scale: scale, pos: prev.pos }
        if (next.mode === prev.mode && Math.abs(next.scale - prev.scale) < 0.001) return
        if (pending) revert()
        pending = { name: m.name, prev: prev, next: next }
        applyCfg(m.name, next)
        countdown = 15
        tick.restart()
    }
    function keep() {
        if (!pending) return
        tick.stop()
        pending = null
        saveLater.restart()
    }
    function revert() {
        if (!pending) return
        tick.stop()
        const p = pending
        pending = null
        applyCfg(p.name, p.prev)
    }
    Timer { id: tick; interval: 1000; repeat: true; onTriggered: { if (--root.countdown <= 0) root.revert() } }
    Timer { id: saveLater; interval: 500; onTriggered: { saver.armed = true; query.running = false; query.running = true } }

    // Guardado en minimo/monitores.lua (formato del archivo que requiere hyprland.lua).
    QtObject { id: saver; property bool armed: false }
    onMonitorsChanged: if (saver.armed) { saver.armed = false; writeOutputs() }
    function writeOutputs() {
        let txt = "-- Monitores de esta PC — escrito por Ajustes › Pantalla de Minimo OS.\n\n"
        txt += 'hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })\n'
        for (const m of monitors) txt += rule(m.name, { mode: modeOf(m), pos: posOf(m), scale: m.scale }) + "\n"
        writer.command = ["sh", "-c", 'f="$1"; mkdir -p "$(dirname "$f")"; [ -e "$f" ] && { [ -e "$f.bak" ] || cp -a "$f" "$f.bak"; }; printf "%s" "$2" > "$f.tmp" && mv "$f.tmp" "$f"', "w", outputsFile, txt]
        writer.running = true
    }
    Process { id: writer }

    SectionTitle { text: I18n.tr("Monitores") }

    Repeater {
        model: root.monitors
        delegate: Rectangle {
            id: mcard
            required property var modelData
            readonly property var m: modelData
            property bool listOpen: false
            width: root.width
            height: mcol.implicitHeight + 32
            radius: 20
            color: Theme.surface

            Column {
                id: mcol
                x: 18; y: 16
                width: parent.width - 36
                spacing: 14

                Row {
                    spacing: 12
                    Rectangle {
                        width: 40; height: 40; radius: 12; color: Theme.field
                        Icon { anchors.centerIn: parent; name: "display"; size: 22 }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: (mcard.m.make && mcard.m.model) ? mcard.m.model : mcard.m.name; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Text { text: mcard.m.name + " · " + mcard.m.width + "×" + mcard.m.height + " · " + Math.round(mcard.m.refreshRate) + " Hz · ×" + mcard.m.scale; color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12 }
                    }
                }

                // Resolución y frecuencia (desplegable).
                Text { text: I18n.tr("Resolución"); color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13 }
                Rectangle {
                    width: parent.width; height: 40; radius: 20; color: Theme.field
                    Text {
                        x: 18; anchors.verticalCenter: parent.verticalCenter
                        text: mcard.m.width + " × " + mcard.m.height + "  ·  " + mcard.m.refreshRate.toFixed(2) + " Hz"
                        color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13
                    }
                    Icon { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; name: "chevron"; size: 18; rotation: mcard.listOpen ? 180 : 0 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: mcard.listOpen = !mcard.listOpen }
                }
                Rectangle {
                    visible: mcard.listOpen
                    width: parent.width; height: Math.min(240, modes.contentHeight + 12); radius: 20; color: Theme.field
                    clip: true
                    ListView {
                        id: modes
                        anchors.fill: parent; anchors.margins: 6
                        model: mcard.listOpen ? mcard.m.availableModes : []   // sin delegados mientras está cerrada
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Rectangle {
                            required property string modelData
                            readonly property string mode: modelData.replace("Hz", "")
                            readonly property bool cur: mode === root.modeOf(mcard.m)
                            width: modes.width; height: 34; radius: 17
                            color: mm.containsMouse ? Theme.hover : "transparent"
                            Text {
                                x: 14; anchors.verticalCenter: parent.verticalCenter
                                text: modelData.replace("x", " × ").replace("@", "  ·  ").replace("Hz", " Hz")
                                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13
                                font.weight: parent.cur ? Font.DemiBold : Font.Normal
                            }
                            Icon { visible: parent.cur; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; name: "check"; size: 16 }
                            MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { mcard.listOpen = false; root.request(mcard.m, parent.mode, mcard.m.scale) } }
                        }
                    }
                }

                // Escala (segmentado).
                Text { text: I18n.tr("Escala"); color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13 }
                Rectangle {
                    width: parent.width; height: 40; radius: 20; color: Theme.field
                    Row {
                        anchors.fill: parent; anchors.margins: 4
                        Repeater {
                            model: root.scales
                            delegate: Rectangle {
                                required property real modelData
                                readonly property bool cur: Math.abs(modelData - mcard.m.scale) < 0.01
                                width: (parent.width) / root.scales.length; height: parent.height; radius: height / 2
                                color: cur ? Theme.fill : (sm.containsMouse ? Theme.hover : "transparent")
                                Text { anchors.centerIn: parent; text: "×" + modelData; color: parent.cur ? Theme.onAccent : Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13; font.weight: parent.cur ? Font.DemiBold : Font.Normal }
                                MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.request(mcard.m, root.modeOf(mcard.m), modelData) }
                            }
                        }
                    }
                }
            }
        }
    }

    SectionTitle { text: I18n.tr("Brillo y color") }
    Column {
        width: parent.width
        spacing: 10
        MSlider {
            width: parent.width; icon: "sun"
            from: 0.3; to: 1.0
            value: DisplayState.brightness
            valueText: Math.round(value * 100) + "%"
            onMoved: v => DisplayState.set(DisplayState.saturation, v)
        }
        MSlider {
            width: parent.width; icon: "drop"
            from: 0; to: 2
            value: DisplayState.saturation
            valueText: Math.round(value * 100) + "%"
            iconClickable: true
            onIconClicked: DisplayState.set(1.0, DisplayState.brightness)
            onMoved: v => DisplayState.set(Math.abs(v - 1) < 0.04 ? 1.0 : v, DisplayState.brightness)
        }
        Text { text: I18n.tr("Por software (shader de Hyprland). Hacé clic en la gota para volver al 100%."); color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 11 }
    }
}
