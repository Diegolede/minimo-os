// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
QtObject {
    readonly property bool sleeping: false
    readonly property bool unattended: false
    function wake() {}
    function sleepNow() {}
}
