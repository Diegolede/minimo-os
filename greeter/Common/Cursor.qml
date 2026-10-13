// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
// Cursor de la pantalla de inicio: lo alimenta el MouseArea de Login.qml (coordenadas de la ventana).
QtObject {
    property int users: 0
    property real x: -1
    property real y: -1
    property bool ok: false
    property real lastMove: 0
    function acquire() { users++ }
    function release() { users = Math.max(0, users - 1) }
    function move(nx, ny) { x = nx; y = ny; ok = true; lastMove = Date.now() }
}
