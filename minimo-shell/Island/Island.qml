// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick.Effects
import "../Common"

// Ventana de la isla: layer-shell arriba, overlay, sin reservar espacio.
// Una sola región de hover (hoverZone) en la máscara de input: cuando la isla
// está oculta es una franja de 3px; cuando se muestra crece hasta cubrir la isla.
PanelWindow {
    id: win

    property bool expanded: false
    property bool panel: false            // panel deslizable abierto
    // Qué panel: izquierda→derecha = "status" (recursos), derecha→izquierda = "apps" (apps en segundo plano),
    // hacia abajo = "pet" (Minimo como mascota).
    property string panelKind: "status"
    readonly property bool open: expanded || panel
    // Mientras se arrastra el puntero puede salir de la zona: sigue contando como encima
    // (si no, el auto-ocultar escondía la isla a mitad del gesto y lo cortaba).
    readonly property bool hovered: hoverZone.containsMouse || hoverZone.pressed
    property bool shown: true
    // Ocultamiento inteligente: hay ventanas en el escritorio activo del monitor de ESTA isla.
    // Solo se evalúa con la opción activa; los escritorios especiales (id < 0) no cuentan.
    readonly property var monitorWs: DisplayState.islandSmartHide ? (Hyprland.monitorFor(win.screen)?.activeWorkspace ?? null) : null
    readonly property int wsWindows: monitorWs && monitorWs.id > 0 ? monitorWs.toplevels.values.length : 0
    readonly property bool occupied: wsWindows > 0
    readonly property bool hideWanted: DisplayState.islandAutoHide || (DisplayState.islandSmartHide && occupied && !Recorder.recording)

    anchors { top: true; left: true; right: true; bottom: win.open }
    implicitHeight: Theme.maxExpandedH + Theme.topMargin + 8
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "minimo-island"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { x: win.open ? 0 : hoverZone.x; y: 0; width: win.open ? win.width : hoverZone.width; height: win.open ? win.height : hoverZone.height }

    function collapse() { expanded = false; panel = false }
    // Mascota apagada con su panel abierto: se cierra (no queda nada de la mascota en pantalla).
    Connections { target: DisplayState; function onPetEnabledChanged() { if (!DisplayState.petEnabled && win.panel && win.panelKind === "pet") win.collapse() } }

    // Auto-ocultar
    Timer {
        id: hideTimer
        interval: Theme.hideDelay
        onTriggered: if (win.hideWanted && !win.hovered && !win.open && !menu.searchFocused && Recorder.notice === "" && Notifs.current === null) win.shown = false
    }
    onHoveredChanged: {
        Notifs.hovers = Math.max(0, Notifs.hovers + (hovered ? 1 : -1))
        if (hovered) { hideTimer.stop(); shown = true }
        else if (!open) hideTimer.restart()
    }
    onPanelChanged: {
        pill.forceActiveFocus()
        if (panel) { hideTimer.stop(); shown = true }
        else if (!hovered) hideTimer.restart()
    }
    onExpandedChanged: {
        // Al abrir y al cerrar, el foco va a la píldora (no al buscador), así no
        // queda el cursor "|" parpadeando. El buscador se activa solo con un clic.
        menu.opened(); pill.forceActiveFocus(); unfocusLater.restart()
        if (expanded) { hideTimer.stop(); shown = true }
        else if (!hovered) hideTimer.restart()
    }
    Timer { id: unfocusLater; interval: 150; onTriggered: { menu.opened(); pill.forceActiveFocus() } }
    Component.onCompleted: hideTimer.restart()
    // Si se desactiva el auto-ocultar, la isla queda siempre visible.
    Connections {
        target: DisplayState
        function onIslandAutoHideChanged() { win.syncHide() }
        function onIslandSmartHideChanged() { win.syncHide() }
    }
    // Reactivo a abrir/cerrar/mover ventanas y cambiar de escritorio (eventos de Hyprland).
    onHideWantedChanged: syncHide()
    // Tras cerrar/mover ventanas se refresca la lista de toplevels (un evento, sin sondeo).
    Connections {
        target: Hyprland
        enabled: DisplayState.islandSmartHide
        function onRawEvent(ev) {
            const n = ev.name
            if (n === "closewindow" || n === "movewindowv2" || n === "openwindow") toplevelsLater.restart()
        }
    }
    // Una sola actualización por ráfaga de eventos, fuera del manejador de eventos de Hyprland.
    Timer { id: toplevelsLater; interval: 120; onTriggered: Hyprland.refreshToplevels() }
    function syncHide() {
        if (!hideWanted) { hideTimer.stop(); shown = true }
        else if (!hovered && !open) hideTimer.restart()
    }

    // Mensajes de la grabadora: mostrar la isla mientras dure el aviso.
    Connections {
        target: Recorder
        function onNoticeChanged() {
            if (Recorder.notice !== "") { win.shown = true; hideTimer.stop() }
            else if (!win.hovered && !win.open) hideTimer.restart()
        }
    }

    // Notificaciones: la isla aparece mientras haya una en pantalla; el mouse encima pausa el tiempo.
    Connections {
        target: Notifs
        function onCurrentChanged() {
            if (Notifs.current !== null) { win.shown = true; hideTimer.stop() }
            else if (!win.hovered && !win.open) hideTimer.restart()
        }
    }
    // Cada isla suma/resta su hover (con varios monitores no se pisan entre sí).
    Component.onDestruction: if (hovered) Notifs.hovers = Math.max(0, Notifs.hovers - 1)

    // Clic afuera de la isla mientras está expandida: colapsa.
    MouseArea {
        anchors.fill: parent
        enabled: win.open
        acceptedButtons: Qt.AllButtons
        onPressed: win.collapse()
    }

    // Región única de hover/input. Nunca se reemplaza por otro item.
    // También es el ÚNICO receptor de clics de la isla compacta (cubre toda la píldora y
    // el margen superior, con su tamaño final aunque la píldora esté animando).
    MouseArea {
        id: hoverZone
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: win.expanded ? Qt.ArrowCursor : Qt.PointingHandCursor
        // Margen extra alrededor de la píldora: un clic/arrastre que empieza justo en el
        // borde no "se escapa" a la ventana de abajo (que seleccionaría su texto).
        readonly property int pad: 8
        x: win.shown ? pill.x - pad : 0
        y: 0
        width: win.shown ? pill.width + pad * 2 : win.width
        height: win.shown ? Theme.topMargin + pill.height + pad : 3

        preventStealing: true
        // Clic → menú (al soltar). Arrastre horizontal (>8 px) → panel de estado del sistema;
        // con el panel abierto, deslizar de nuevo lo cierra. La píldora sigue al dedo (elástico).
        property real pressX: 0
        property real pressY: 0
        property bool dragging: false
        property bool pulling: false     // arrastre hacia abajo (mascota)
        property real dragDy: 0
        property real dragDx: 0
        // Velocidad (px/ms, suavizada) para decidir con un gesto rápido y corto.
        property real vel: 0
        property real velY: 0
        property real lastY: 0
        property real lastX: 0
        property real lastT: 0
        // Coordenadas de ventana: la zona se mueve con la píldora mientras se arrastra.
        onPressed: m => { const p = mapToItem(null, m.x, m.y); pressX = p.x; pressY = p.y; dragging = false; pulling = false; dragDx = 0; dragDy = 0; vel = 0; velY = 0; lastX = pressX; lastY = pressY; lastT = Date.now() }
        onPositionChanged: m => {
            if (!pressed || win.expanded) return
            const p = mapToItem(null, m.x, m.y), now = Date.now()
            if (now > lastT) {
                vel = vel * 0.6 + 0.4 * (p.x - lastX) / (now - lastT)
                velY = velY * 0.6 + 0.4 * (p.y - lastY) / (now - lastT)
                lastX = p.x; lastY = p.y; lastT = now
            }
            const dx = p.x - pressX, dy = p.y - pressY
            // La dirección se decide una sola vez, por el eje dominante, al pasar 6 px:
            // horizontal → paneles; hacia abajo → mascota (hacia arriba no hace nada).
            if (!dragging && !pulling && Math.hypot(dx, dy) > 6) {
                if (Math.abs(dx) > Math.abs(dy)) dragging = true
                else if (dy > 0 && !win.panel) pulling = true
            }
            if (dragging) dragDx = dx
            if (pulling) dragDy = Math.max(0, dy)
        }
        onReleased: m => {
            // Con una notificación: clic = abrir la app, clic derecho = descartar.
            if (!dragging && !pulling && !win.open && Notifs.current !== null) {
                if (m.button === Qt.RightButton) Notifs.dismiss(); else Notifs.activate()
                dragging = false; dragDx = 0; return
            }
            if (m.button === Qt.RightButton) return
            if (pulling) {
                if (Date.now() - lastT > 80) velY = 0
                // Hacia abajo: panel de la mascota; con la mascota apagada, el mismo menú que un clic.
                if (dragDy > 24 || (velY > 0.5 && dragDy > 10)) {
                    if (DisplayState.petEnabled) { win.panelKind = "pet"; win.panel = true }
                    else win.expanded = true
                }
                pulling = false; dragDy = 0; return
            }
            if (dragging) {
                if (Date.now() - lastT > 80) vel = 0          // se detuvo antes de soltar: no es un "fling"
                const fling = Math.abs(vel) > 0.6 && Math.abs(dragDx) > 16
                if (Math.abs(dragDx) > 40 || fling) {
                    if (win.panel) win.panel = false          // abierto: deslizar en cualquier sentido cierra
                    else { win.panelKind = (fling ? vel : dragDx) > 0 ? "status" : "apps"; win.panel = true }
                }
            } else if (!win.open) win.expanded = true
            dragging = false; dragDx = 0
        }
        onCanceled: { dragging = false; dragDx = 0; pulling = false; dragDy = 0 }
        // Rueda sobre la isla compacta: escritorio anterior/siguiente.
        onWheel: w => { if (!win.open) Workspaces.wheel(w.angleDelta.y) }
    }


    // Sombra suave y difusa detrás de la tarjeta (no recorta, no recibe input).
    Rectangle {
        id: shadowSrc
        x: pill.x; y: pill.y; width: pill.width; height: pill.height
        radius: pill.radius
        color: Theme.card
        Behavior on color { ColorAnimation { duration: 250 } }
        opacity: win.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.shadow
            shadowBlur: 1.0
            blurMax: 40
            shadowVerticalOffset: 8
            autoPaddingEnabled: true
        }
    }

    Rectangle {
        id: pill
        // Elástico: mientras se arrastra, la píldora se estira y se corre un poco con el dedo.
        readonly property real pull: hoverZone.pulling ? hoverZone.dragDy / (1 + hoverZone.dragDy / 70) : 0
        readonly property real rubber: hoverZone.dragging ? hoverZone.dragDx / (1 + Math.abs(hoverZone.dragDx) / 60) : 0
        width: win.expanded ? Theme.expandedW
             : win.panel ? Theme.expandedW
             : Math.max(Theme.compactW, compact.implicitWidth + Theme.compactPadX * 2) + Math.abs(rubber) * 1.2
        height: win.expanded ? Math.min(menu.implicitHeight, Theme.maxExpandedH)
              : win.panel ? Math.min(win.panelKind === "apps" ? apps.implicitHeight : win.panelKind === "pet" ? pet.implicitHeight : status.implicitHeight, Theme.maxExpandedH)
              : compact.implicitHeight + pull * 0.65   // al tirar hacia abajo: se estira y baja un poco
        x: (win.width - width) / 2 + rubber * 0.5
        y: win.shown ? Theme.topMargin + pull * 0.35 : -height - 64
        radius: Math.min(height / 2, Theme.radiusCard)
        color: Theme.card
        Behavior on color { ColorAnimation { duration: 250 } }
        clip: true

        // Rebote elástico solo al abrir/cerrar. Con la isla ya abierta (cambio de página: calendario,
        // portapapeles…) el cambio de tamaño es un deslizamiento suave, sin rebote.
        property bool settled: false
        Timer { id: settleTimer; interval: Theme.durNormal + 80; onTriggered: pill.settled = win.open }
        Connections { target: win; function onOpenChanged() { pill.settled = false; if (win.open) settleTimer.restart() } }
        Behavior on width { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutBack; easing.overshoot: pill.settled ? 0 : 0.9 } }
        // Durante el tirón la píldora sigue al dedo sin retraso (la animación vuelve al soltar).
        Behavior on height { enabled: !hoverZone.pulling; NumberAnimation { duration: Theme.durNormal + 40; easing.type: Easing.OutBack; easing.overshoot: pill.settled ? 0 : 0.7 } }
        Behavior on y { enabled: !hoverZone.pulling; NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutQuint } }

        focus: win.open
        // Escape en una subpágina (escritorios, portapapeles, calendario…) vuelve al menú;
        // en el menú principal cierra la isla.
        Keys.onEscapePressed: { if (win.expanded && menu.page !== "menu") menu.page = "menu"; else win.collapse() }

        IslandCompact {
            id: compact
            anchors.horizontalCenter: parent.horizontalCenter
            // con vista previa crece hacia abajo desde arriba; si no, centrada (tirón incluido)
            y: compact.hasShot ? 0 : (parent.height - height) / 2
            active: win.shown && !win.open
            opacity: win.open ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        }

        IslandMenu {
            id: menu
            width: Theme.expandedW
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            open: win.expanded
            opacity: win.expanded ? 1 : 0
            visible: opacity > 0
            enabled: win.expanded
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            onDone: win.collapse()
        }

        StatusPanel {
            id: status
            width: Theme.expandedW
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            open: win.panel && win.panelKind === "status"
            opacity: win.panel && win.panelKind === "status" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        }
        AppsPanel {
            id: apps
            width: Theme.expandedW
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            open: win.panel && win.panelKind === "apps"
            opacity: win.panel && win.panelKind === "apps" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        }
        PetPanel {
            id: pet
            width: Theme.expandedW
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            open: win.panel && win.panelKind === "pet"
            opacity: win.panel && win.panelKind === "pet" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            onDone: win.collapse()
        }
    }

    // Control externo (ipc "island"): show/hide/open/close.
    Connections {
        target: CharacterBus
        function onIslandCommand(cmd) {
            if (cmd === "show") { win.shown = true; hideTimer.stop() }
            else if (cmd === "hide") { win.expanded = false; win.shown = false }
            else if (cmd === "open") win.expanded = true
            else if (cmd === "clipboard") {
                // Super+V: abre la isla en el portapapeles (o la cierra si ya está ahí).
                if (win.expanded && menu.page === "clip") win.collapse()
                else { win.panel = false; win.expanded = true; menu.showClipboard() }
            }
            else if (cmd === "close") win.collapse()
            else if (cmd === "pet" && !DisplayState.petEnabled) { win.panel = false; win.expanded = true }
            else if (cmd === "status" || cmd === "apps" || cmd === "pet") {
                // Si ya está abierto el otro panel, cambiar a este en vez de cerrar.
                win.panel = !(win.panel && win.panelKind === cmd)
                win.panelKind = cmd
            }
        }
    }

    // Reacciones del personaje.
    onShownChanged: if (shown && !expanded) compact.character.hop()
    Connections {
        target: win
        function onExpandedChanged() {
            if (win.expanded) menu.character.opened()
        }
    }
}
