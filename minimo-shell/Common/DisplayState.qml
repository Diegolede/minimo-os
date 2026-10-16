// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Brillo y saturación por software (shader de Hyprland), persistidos en
// ~/.config/minimo-os/state.json y reaplicados al iniciar. También guarda el fondo.
Singleton {
    id: root
    property real saturation: 1.0
    property real brightness: 1.0
    property bool loaded: false
    property string wallpaper: ""
    property var wallpaperHistory: []       // fondos elegidos (más reciente primero)
    property bool islandAutoHide: true      // ocultar la isla automáticamente
    property bool islandSmartHide: false    // ocultar solo si hay ventanas en el escritorio
    property bool characterAnimated: true   // personaje animado (si no, quieto)
    property string theme: "light"          // "light" | "dark"
    property int sleepMinutes: 1            // dormir tras inactividad (1, 2 o 5 min)
    // Menú de la isla: elementos fijados (en orden) y accesos propios { id, label, cmd }.
    property var pins: ["volume", "brightness", "vibrance", "terminal", "record", "capture", "desktops", "notes", "browser", "files"]
    property var customItems: []
    // Idioma: el guardado; si no hay, el del sistema (LANG en… → inglés, si no español).
    property string language: (Quickshell.env("LANG") || "").startsWith("en") ? "en" : "es"
    property var pinOrder: []               // orden de todos los elementos del menú (fijados o no)
    // Fondo animado (video o GIF con mpvpaper). Vacío = fondo estático.
    property string liveWallpaper: ""
    property bool livePauseCovered: true    // pausar si hay ventanas encima

    function setWallpaper(path) {
        wallpaper = path
        if (path !== "") wallpaperHistory = [path].concat(wallpaperHistory.filter(p => p !== path)).slice(0, 24)
        save()
    }
    // Quitar un fondo de la lista (y dejar de usarlo si era el actual).
    function removeWallpaper(path) {
        wallpaperHistory = wallpaperHistory.filter(p => p !== path)
        if (wallpaper === path) wallpaper = ""
        save()
    }
    function forgetWallpapers(missing) { wallpaperHistory = wallpaperHistory.filter(p => missing.indexOf(p) < 0); save() }
    function setIslandAutoHide(v) { islandAutoHide = v; if (v) islandSmartHide = false; save() }
    // Excluyentes: activar uno apaga el otro.
    function setIslandSmartHide(v) { islandSmartHide = v; if (v) islandAutoHide = false; save() }
    function setCharacterAnimated(v) { characterAnimated = v; save() }
    function setSleepMinutes(v) { sleepMinutes = v; save() }
    function setTheme(v) { theme = v; save() }
    function setPins(list) { pins = list; save() }
    function setPinOrder(list) { pinOrder = list; save() }
    function setLanguage(v) { language = v === "en" ? "en" : "es"; save() }
    function setCustomItems(list) { customItems = list; save() }
    function setLiveWallpaper(p) { liveWallpaper = p; save() }
    function setLivePauseCovered(v) { livePauseCovered = v; save() }
    // Empuja el tema al singleton Theme (sin dependencia inversa: evita init cíclico).
    onThemeChanged: Theme.dark = theme === "dark"
    function save() {
        file.setText(JSON.stringify({ saturation: root.saturation, brightness: root.brightness, wallpaper: root.wallpaper, wallpaperHistory: root.wallpaperHistory,
                                     islandAutoHide: root.islandAutoHide, islandSmartHide: root.islandSmartHide, characterAnimated: root.characterAnimated,
                                     sleepMinutes: root.sleepMinutes, theme: root.theme, language: root.language,
                                     pins: root.pins, pinOrder: root.pinOrder, customItems: root.customItems,
                                     liveWallpaper: root.liveWallpaper, livePauseCovered: root.livePauseCovered }, null, 2))
    }

    readonly property string stateDir: Quickshell.env("HOME") + "/.config/minimo-os"
    readonly property string applyScript: Qt.resolvedUrl("../scripts/apply-color.sh").toString().replace("file://", "")

    function set(sat, bri) {
        saturation = Math.max(0, Math.min(2, sat))
        brightness = Math.max(0.3, Math.min(1, bri))
        applyTimer.restart()
    }

    Timer {
        id: applyTimer
        interval: 150
        onTriggered: {
            Quickshell.execDetached([root.applyScript, root.saturation.toFixed(3), root.brightness.toFixed(3)])
            root.save()
        }
    }

    Process {
        running: true
        command: ["mkdir", "-p", root.stateDir]
        onExited: file.path = root.stateDir + "/state.json"
    }

    FileView {
        id: file
        blockLoading: false
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text())
                root.wallpaper = s.wallpaper ?? ""
                root.wallpaperHistory = s.wallpaperHistory ?? (root.wallpaper ? [root.wallpaper] : [])
                root.islandAutoHide = s.islandAutoHide ?? true
                root.islandSmartHide = (s.islandSmartHide ?? false) && !root.islandAutoHide
                root.characterAnimated = s.characterAnimated ?? true
                root.sleepMinutes = s.sleepMinutes ?? 1
                root.theme = s.theme === "dark" ? "dark" : "light"
                if (s.language === "es" || s.language === "en") root.language = s.language
                if (Array.isArray(s.pins)) root.pins = s.pins.filter(p => typeof p === "string")
                if (Array.isArray(s.pinOrder)) root.pinOrder = s.pinOrder.filter(p => typeof p === "string")
                root.liveWallpaper = typeof s.liveWallpaper === "string" ? s.liveWallpaper : ""
                root.livePauseCovered = s.livePauseCovered ?? true
                if (Array.isArray(s.customItems)) root.customItems = s.customItems.filter(c => c && c.id && c.label && c.cmd)
                root.set(s.saturation ?? 1.0, s.brightness ?? 1.0)
            } catch (e) {}
            root.loaded = true
        }
        onLoadFailed: root.loaded = true
    }
}
