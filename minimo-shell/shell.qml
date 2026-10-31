//@ pragma UseQApplication
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell
import "Island"
import "Wallpaper"
import "Launcher"
import "Settings"
import "Overview"
import "Common"

// Minimo OS shell root: fondo de pantalla e isla por monitor.
ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Wallpaper {
            required property var modelData
            screen: modelData
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: Island {
            required property var modelData
            screen: modelData
        }
    }
    Launcher {}
    // Ajustes se monta al primer open y se libera al cerrar (tras la animación).
    Loader {
        active: SettingsState.open || (item !== null && item.visible)
        sourceComponent: SettingsWindow {}
    }
    Overview {}
}
