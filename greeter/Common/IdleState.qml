// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
// Sueño de Minimo en la pantalla de inicio: lo maneja Login.qml (1 min sin actividad).
QtObject {
    property bool sleeping: false
    readonly property bool unattended: false
    function wake() { sleeping = false }
    function sleepNow() { sleeping = true }
}
