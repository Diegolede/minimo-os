// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications

// Servidor de notificaciones de Minimo OS (org.freedesktop.Notifications).
// Las muestra de a una en la isla compacta, en cola (máx. 8), ~5 s cada una.
// Si la app de origen está enfocada, el aviso es más breve (2,5 s): ya la estás viendo.
// "No molestar": qs ipc call notifs dnd  (las críticas se muestran igual).
Singleton {
    id: root
    property var queue: []
    readonly property var current: queue.length > 0 ? queue[0] : null
    property bool dnd: false
    // Mouse encima de alguna isla (una por monitor): no corre el tiempo.
    property int hovers: 0
    readonly property bool paused: hovers > 0

    function readMs(n) {
        const len = ((n.summary || "") + (n.body || "")).length
        return Math.min(10000, 5000 + Math.max(0, len - 40) * 40)
    }
    // Avisos que llegaron con "No molestar": al apagarlo se dice cuántos fueron.
    property int missed: 0
    function setDnd(on) {
        dnd = on
        if (on) { missed = 0; Laptop.say(I18n.tr("No molestar activado"), "info", 1800) }
        else Laptop.say(missed > 0 ? I18n.tr("No molestar desactivado · %1 avisos silenciados", missed) : I18n.tr("No molestar desactivado"), "info", 2500)
    }
    function keyOf(n) { return ((n.desktopEntry || n.appName || "") + "").toLowerCase() }
    // ¿La app de la notificación es la ventana enfocada?
    function fromFocused(n) {
        const t = Hyprland.activeToplevel
        const cls = t && t.lastIpcObject ? ((t.lastIpcObject["class"] || "") + "").toLowerCase() : ""
        const k = keyOf(n)
        return k !== "" && cls !== "" && (cls.includes(k) || k.includes(cls))
    }
    function iconOf(n) {
        if (!n) return ""
        if (n.image) return n.image
        const p = Quickshell.iconPath(n.appIcon || n.desktopEntry || "", true)
        if (p !== "") return p
        const e = n.desktopEntry ? DesktopEntries.byId(n.desktopEntry) : DesktopEntries.heuristicLookup(n.appName || "")
        return e ? Quickshell.iconPath(e.icon, true) : ""
    }

    // Miniatura (p. ej. una captura): la imagen de la notificación si es un archivo/imagen propia
    // (hint image-path o image-data), no un icono de app.
    function thumbOf(n) {
        if (!n) return ""
        const h = n.hints || {}
        const p = h["image-path"] || h["image_path"] || ""
        if (typeof p === "string" && (p.startsWith("file://") || p.startsWith("/"))) return p.startsWith("/") ? "file://" + p : p
        return n.image && !n.appIcon && n.image !== "" ? n.image : ""
    }

    // Saca una notificación concreta de la cola. Nunca "la primera a ciegas": invocar una
    // acción puede cerrar la notificación (closed → filtro) antes de que volvamos acá, y
    // quitar queue[0] después se llevaría la siguiente sin mostrarla.
    function drop(n) { queue = queue.filter(x => x !== n) }
    // Cerrarla solo si sigue viva: si la app ya la cerró (p. ej. al invocar una acción),
    // dismiss() sobre un objeto destruido da "Cannot close destroyed notification".
    function finish(n) { const live = queue.indexOf(n) >= 0; drop(n); if (live) n.dismiss() }
    // Cierra la actual (el usuario la descartó o se venció el tiempo).
    function dismiss() { const n = current; if (n) finish(n) }
    // Clic en el aviso: acción "default" si existe; si no, trae la app (desminimiza y enfoca).
    function activate() {
        const n = current
        if (!n) return
        const def = Array.from(n.actions || []).find(a => a.identifier === "default")
        const open = n.hints ? n.hints["x-minimo-open"] : ""
        if (n.minimo && n.action === "atajos") { SettingsState.section = "atajos"; SettingsState.show() }
        else if (n.minimo) { if (n.action) CharacterBus.islandCommand(n.action) }   // aviso propio: abre su panel
        else if (typeof open === "string" && open.startsWith("/")) Quickshell.execDetached(["xdg-open", open])   // captura: abrirla
        else if (def) def.invoke()
        else Quickshell.execDetached([Qt.resolvedUrl("../scripts/focus-app.py").toString().replace("file://", ""),
                                      n.desktopEntry || "", n.appName || ""])
        finish(n)
    }
    // Avisos propios de Minimo OS (p. ej. la mascota) por el mismo camino que los de las apps:
    // misma cola, mismo tiempo en pantalla, respetan "No molestar". `tag` identifica el aviso
    // (uno por tag a la vez) y `action` es el comando de isla al hacer clic (p. ej. "pet").
    function post(o) {
        if (root.dnd) return
        withdraw(o.tag)
        const n = { minimo: true, tag: o.tag, summary: o.summary || "", body: o.body || "", appName: "Minimo OS",
                    appIcon: "", image: "", desktopEntry: "", hints: {}, actions: [], urgency: NotificationUrgency.Normal,
                    action: o.action || "", expire() {}, dismiss() {} }
        let q = root.queue.concat([n])
        while (q.length > 8) { const old = q.splice(1, 1)[0]; old.expire() }
        root.queue = q
    }
    // Retira un aviso propio que ya no corresponde (necesidad atendida, mascota apagada).
    function withdraw(tag) { if (tag) root.queue = root.queue.filter(n => !(n.minimo && n.tag === tag)) }
    function invoke(action) { const n = current; action.invoke(); if (n) finish(n) }

    NotificationServer {
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        imageSupported: true
        persistenceSupported: false
        onNotification: n => {
            const critical = n.urgency === NotificationUrgency.Critical
            if (root.dnd && !critical) { root.missed++; n.expire(); return }
            if (root.queue.indexOf(n) >= 0) return          // reemplazo de una ya en cola: se actualiza sola
            n.tracked = true
            // Si la app cierra/reemplaza la notificación, sale de la cola.
            n.closed.connect(() => { root.queue = root.queue.filter(x => x !== n) })
            let q = root.queue.concat([n])
            while (q.length > 8) { const old = q.splice(1, 1)[0]; old.expire() }
            root.queue = q
        }
    }

    Timer {
        id: life
        // Tiempo de lectura: 5 s base + ~1 s cada 25 caracteres de texto (máx. 10 s).
        interval: root.current ? (root.current.urgency === NotificationUrgency.Critical ? 9000
                                  : root.fromFocused(root.current) ? 2500 : root.readMs(root.current)) : 5000
        running: root.current !== null && !root.paused
        onTriggered: { const n = root.current; if (n) { root.drop(n); n.expire() } }
    }
    onCurrentChanged: if (current) life.restart()

    // Primer inicio: un único aviso de bienvenida con los dos atajos clave (clic: todos los
    // atajos). Minimo guiña. Se marca como visto y no vuelve a aparecer.
    Connections {
        target: DisplayState
        function onLoadedChanged() { if (DisplayState.loaded && !DisplayState.welcomed) welcomeLater.start() }
    }
    Timer {
        id: welcomeLater; interval: 2500
        onTriggered: {
            DisplayState.setWelcomed()
            root.post({ tag: "welcome", summary: I18n.tr("Bienvenido a Minimo OS"),
                        body: I18n.tr("Super + Espacio abre apps · Super + F1 muestra todos los atajos"), action: "atajos" })
            CharacterBus.react("wink")
        }
    }

    IpcHandler {
        target: "notifs"
        function dnd(): string { root.setDnd(!root.dnd); return root.dnd ? "no molestar: sí" : "no molestar: no" }
        function clear(): void { const q = root.queue; root.queue = []; q.forEach(n => n.dismiss()) }
    }
}
