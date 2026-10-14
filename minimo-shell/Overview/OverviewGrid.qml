// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import "../Common"

// Grilla de ventanas: tantas columnas como para que entren todas con el mayor tamaño
// posible (como Exposé). windows: [{ title, icon, badge, aspect, source }].
Item {
    id: root
    property var windows: []
    property int selected: 0
    property bool capture: true
    signal picked(int index)

    readonly property int n: windows.length
    readonly property int gap: 28
    // Columnas que maximizan el ancho de cada tesela (relación 16:10 + 30 px de título).
    readonly property int cols: {
        let best = 1, bestW = 0
        for (let c = 1; c <= Math.max(1, n); c++) {
            const r = Math.ceil(n / c)
            const w = Math.min((width - gap * (c - 1)) / c, ((height - gap * (r - 1)) / r - 30) * 1.6)
            if (w > bestW) { bestW = w; best = c }
        }
        return best
    }
    readonly property int rows: Math.max(1, Math.ceil(n / cols))
    readonly property real tileW: Math.min(480, (width - gap * (cols - 1)) / cols)
    readonly property real tileH: Math.min(tileW / 1.6 + 30, (height - gap * (rows - 1)) / rows)

    function move(dx, dy) {
        if (n === 0) return
        if (dy !== 0) { const t = selected + dy * cols; if (t >= 0 && t < n) selected = t }
        else selected = (selected + dx + n) % n
    }

    Repeater {
        model: root.windows
        delegate: WindowTile {
            required property var modelData
            required property int index
            readonly property int r: Math.floor(index / root.cols)
            readonly property int inRow: r === root.rows - 1 ? root.n - r * root.cols : root.cols
            width: root.tileW; height: root.tileH
            // Filas centradas (la última, incompleta, también).
            x: (root.width - (inRow * root.tileW + (inRow - 1) * root.gap)) / 2 + (index % root.cols) * (root.tileW + root.gap)
            y: (root.height - (root.rows * root.tileH + (root.rows - 1) * root.gap)) / 2 + r * (root.tileH + root.gap)
            title: modelData.title
            icon: modelData.icon
            badge: modelData.badge
            aspect: modelData.aspect
            source: modelData.source
            capture: root.capture
            selected: index === root.selected
            onHovered: root.selected = index
            onPicked: root.picked(index)
        }
    }
}
