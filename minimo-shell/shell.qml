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
    SettingsWindow {}
    Overview {}
}
