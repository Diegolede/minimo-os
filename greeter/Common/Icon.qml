// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick

// Icono de la pantalla de inicio: los mismos SVG de la shell (Fluent UI System Icons, Filled,
// MIT; ver icons/README.md). icons/ es un enlace a minimo-shell/assets/icons (install-greeter
// copia con cp -rL). tone: dark | gray | white; en oscuro se invierten como en la shell.
Image {
    property string name
    property string tone: "dark"
    property int size: 20
    width: size; height: size
    sourceSize: Qt.size(size * 2, size * 2)
    readonly property string resolvedTone: !Theme.dark ? tone : (tone === "dark" ? "white" : tone === "white" ? "dark" : "graydark")
    source: name ? Qt.resolvedUrl("../icons/" + resolvedTone + "/" + name + ".svg") : ""
    smooth: true
}
