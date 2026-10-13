// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
QtObject {
    readonly property bool playing: false
    readonly property bool hasLevel: false
    readonly property real level: 0
    function acquire() {}
    function release() {}
}
