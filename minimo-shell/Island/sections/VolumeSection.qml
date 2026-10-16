// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell.Services.Pipewire
import "../../Common"

// Volumen del sink por defecto (Pipewire nativo). Clic en el icono: silenciar.
MSlider {
    id: root
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.audio !== null
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    visible: ready
    icon: ready && sink.audio.muted ? "mute" : "volume"
    from: 0; to: 1
    value: ready ? (sink.audio.muted ? 0 : sink.audio.volume) : 0
    valueText: ready && sink.audio.muted ? I18n.tr("Silencio") : Math.round(value * 100) + "%"
    iconClickable: true
    onIconClicked: if (ready) sink.audio.muted = !sink.audio.muted
    onMoved: v => { if (ready) { sink.audio.volume = v; if (v > 0) sink.audio.muted = false } }
}
