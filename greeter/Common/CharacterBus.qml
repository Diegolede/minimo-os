// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
QtObject {
    signal react(string name)
    signal gaze(real x, real y, int ms)
    signal pet()
    signal typed()
    signal typingStopped()
    signal squintFor(int ms)
    property int hearts: 0
}
