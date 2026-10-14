// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Common"

// Fondo de pantalla propio: capa Background a pantalla completa, con fundido
// de 400 ms al cambiar. Sin fondo elegido: gris claro neutro. Con fondo animado se oculta.
PanelWindow {
    id: win
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: Theme.wallFallback
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "minimo-wallpaper"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}
    // Con fondo animado (mpvpaper dibuja en su propia capa) esta capa se oculta y suelta la imagen.
    visible: !LiveWallpaper.running

    readonly property string path: DisplayState.wallpaper
    property bool useA: true

    function show(p) {
        const next = useA ? imgB : imgA
        next.source = p ? "file://" + p : ""
        useA = !useA
        freeOld.restart()
    }
    // Tras el fundido, libera la imagen anterior (textura a pantalla completa).
    Timer { id: freeOld; interval: 500; onTriggered: (win.useA ? imgB : imgA).source = "" }
    onPathChanged: if (visible) show(path)
    onVisibleChanged: { if (!visible) { imgA.source = ""; imgB.source = "" } else if (path) show(path) }
    Component.onCompleted: if (path) show(path)

    component Layer: Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize: Qt.size(win.width, win.height)
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
    }
    Layer { id: imgA; opacity: win.useA && status === Image.Ready ? 1 : 0 }
    Layer { id: imgB; opacity: !win.useA && status === Image.Ready ? 1 : 0 }
}
