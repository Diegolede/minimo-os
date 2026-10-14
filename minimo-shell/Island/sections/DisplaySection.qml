// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import "../../Common"

// Brillo y saturación por software (shader de pantalla de Hyprland).
// Cada control se puede fijar o quitar del menú por separado.
Column {
    id: root
    property bool brightness: true
    property bool vibrance: true
    spacing: 8
    MSlider {
        width: parent.width
        visible: root.brightness
        icon: "sun"
        from: 0.3; to: 1.0
        value: DisplayState.brightness
        valueText: Math.round(value * 100) + "%"
        onMoved: v => DisplayState.set(DisplayState.saturation, v)
    }
    MSlider {
        width: parent.width
        visible: root.vibrance
        icon: "drop"
        from: 0; to: 2
        value: DisplayState.saturation
        valueText: Math.round(value * 100) + "%"
        iconClickable: true
        onIconClicked: DisplayState.set(1.0, DisplayState.brightness)
        onMoved: v => DisplayState.set(Math.abs(v - 1) < 0.04 ? 1.0 : v, DisplayState.brightness)
    }
}
