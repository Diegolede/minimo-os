// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick

// Icono monocromo (Fluent UI System Icons, Filled; mapa en assets/icons/map.json) desde
// assets/icons/<tono>/<nombre>.svg.
Image {
    property string name
    property string tone: "dark"   // dark | gray | white
    property int size: 20
    width: size; height: size
    sourceSize: Qt.size(size * 2, size * 2)
    // En modo oscuro se invierten: "dark" (principal) → blanco, "white" (sobre relleno) → oscuro.
    readonly property string resolvedTone: !Theme.dark ? tone : (tone === "dark" ? "white" : tone === "white" ? "dark" : "graydark")
    source: name ? Qt.resolvedUrl("../assets/icons/" + resolvedTone + "/" + name + ".svg") : ""
    smooth: true
}
