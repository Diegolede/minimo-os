// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import "../Common"
import "../Character"
import "sections"
import Quickshell.Io

// Panel de estado del sistema (se abre deslizando sobre la isla): Internet, Recursos, Dispositivos.
// Consulta datos solo mientras está abierto.
Item {
    id: root
    property bool open: false
    implicitHeight: col.implicitHeight + 32
    // La isla limita el alto (Theme.maxExpandedH): si el contenido no entra, se desplaza
    // dentro del panel con bordes difuminados en vez de cortarse.
    height: Math.min(implicitHeight, Theme.maxExpandedH)

    onOpenChanged: {
        if (!open) { freeArmed = false; freeDisarm.stop(); freeApps = [] }
        if (open) flick.contentY = 0
        if (open) ppGet.running = true
        open ? SysStatus.acquire() : SysStatus.release()
        if (open) greetLater.restart()
        if (open) { enterAnim.restart() } else { enterAnim.stop(); enter = 1 }
    }
    // Entrada escalonada y suave: cada bloque aparece ~35 ms después del anterior.
    property real enter: 1
    NumberAnimation { id: enterAnim; target: root; property: "enter"; from: 0; to: 1; duration: 520 }
    onEnterChanged: {
        const kids = col.children, n = kids.length
        for (let i = 0; i < n; i++) {
            const t = Math.max(0, Math.min(1, (root.enter * 520 - i * 35) / 220))
            kids[i].opacity = 1 - Math.pow(1 - t, 3)
        }
    }
    Timer { id: greetLater; interval: 280; onTriggered: chr.react("greet") }

    // Ánimo del personaje según el estado: sin internet → preocupado; CPU >85 % o
    // temperatura alta (≥85 °C CPU / ≥85 °C GPU) → cansado; si no, feliz.
    readonly property string mood: SysStatus.known && !SysStatus.online ? "worried"
        : (r && (r.cpu > 85 || (r.temp !== null && r.temp !== undefined && r.temp >= 85)))
          || (SysStatus.gpu && SysStatus.gpu.temp >= 85) ? "tired" : ""
    Component.onDestruction: if (open) SysStatus.release()

    // Liberar memoria (estilo Android): primer clic arma (negro persistente, como Apagar),
    // segundo clic cierra todas las ventanas menos la enfocada con el cierre normal de
    // Hyprland (nunca mata procesos). Cerrar el panel cancela.
    property bool freeArmed: false
    property string freeMsg: ""
    property bool freeDone: false      // estado "Listo" breve tras liberar
    Timer { id: freeDoneT; interval: 2600; onTriggered: root.freeDone = false }
    function pressFree() {
        if (freeProc.running) return
        if (!freeArmed) {
            freeArmed = true; freeDone = false; freeMsg = ""; freeApps = []; freeCount = -1; freeDisarm.restart()
            freePeek.running = true          // qué se va a cerrar (sin cerrar nada)
            return
        }
        freeArmed = false; freeDisarm.stop()
        freeMsg = I18n.tr("Liberando…")
        freeProc.running = true
    }
    Timer { id: freeDisarm; interval: 4000; onTriggered: root.freeArmed = false }
    property var freeApps: []          // [{ name, mb }] de la vista previa
    property int freeCount: -1
    function mb(v) { return v >= 1024 ? (v / 1024).toFixed(1).replace(".", ",") + " GB" : v + " MB" }
    readonly property string freePreview: freeCount < 0 ? I18n.tr("Toca de nuevo para cerrar las demás ventanas")
        : freeApps.slice(0, 3).map(a => a.name + " " + mb(a.mb)).join(" · ") + (freeApps.length > 3 ? " …" : "")
    Process {
        id: freePeek
        command: [Qt.resolvedUrl("../scripts/free-mem.py").toString().replace("file://", ""), "--dry-run"]
        stdout: StdioCollector {
            onStreamFinished: {
                let j = null
                try { j = JSON.parse(text) } catch (e) {}
                if (!j || !root.freeArmed) return
                if (j.closed === 0) {        // nada que cerrar: no tiene sentido confirmar
                    root.freeArmed = false; freeDisarm.stop()
                    root.freeMsg = I18n.tr("No hay otras ventanas abiertas"); freeMsgClear.restart()
                    return
                }
                root.freeCount = j.closed; root.freeApps = j.apps || []
            }
        }
    }
    Timer { id: freeMsgClear; interval: 5000; onTriggered: root.freeMsg = "" }
    Process {
        id: freeProc
        command: [Qt.resolvedUrl("../scripts/free-mem.py").toString().replace("file://", "")]
        stdout: StdioCollector {
            onStreamFinished: {
                let j = null
                try { j = JSON.parse(text) } catch (e) {}
                if (!j) root.freeMsg = ""
                else if (j.closed === 0) root.freeMsg = I18n.tr("No hay otras ventanas abiertas")
                else {
                    const parts = []
                    if (j.ram !== null && j.ram > 0) parts.push("RAM " + (j.ram >= 1024 ? (j.ram / 1024).toFixed(1) + " GB" : j.ram + " MB"))
                    if (j.vram !== null && j.vram > 0) parts.push(I18n.tr("Video") + " " + j.vram + " MB")
                    root.freeMsg = I18n.tr("%1 ventanas cerradas", j.closed) + (parts.length ? " · " + I18n.tr("Liberado: %1", parts.join(", ")) : "")
                }
                freeMsgClear.restart()
                if (j) { root.freeDone = true; freeDoneT.restart() }
            }
        }
    }

    // Perfil de energía (power-profiles-daemon). Se lee al abrir el panel; oculto si no hay servicio.
    property string profile: ""
    Process {
        id: ppGet
        command: ["sh", "-c", "command -v powerprofilesctl >/dev/null && powerprofilesctl get 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.profile = text.trim() }
    }
    property string ppApplied: ""      // confirmación breve "Modo X activado · Deshacer"
    property string ppPrev: ""
    Timer { id: ppAppliedT; interval: 4000; onTriggered: root.ppApplied = "" }
    Process {
        id: ppSet
        onExited: {
            ppGet.running = true
            const m = { "power-saver": I18n.tr("Ahorro"), "balanced": I18n.tr("Equilibrado"), "performance": I18n.tr("Rendimiento") }
            root.ppApplied = m[root.profile] || ""; ppAppliedT.restart()
        }
    }

    // Velocidad de la interfaz Wi-Fi: contadores de /sys cada 2 s, solo con el panel abierto y Wi-Fi.
    property real rxRate: -1
    property real txRate: -1
    property var lastNet: null
    function rate(b) { return b >= 1048576 ? (b / 1048576).toFixed(1).replace(".", ",") + " MB/s" : Math.round(b / 1024) + " KB/s" }
    Timer { interval: 2000; repeat: true; triggeredOnStart: true; running: root.open && Network.hasWifi && Network.ssid !== ""; onTriggered: if (!netStat.running) netStat.running = true
            onRunningChanged: if (!running) { root.lastNet = null; root.rxRate = -1; root.txRate = -1 } }
    Process {
        id: netStat
        command: ["sh", "-c", "for d in /sys/class/net/*; do [ -d \"$d/wireless\" ] && cat \"$d/statistics/rx_bytes\" \"$d/statistics/tx_bytes\" && break; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim().split("\n").map(Number), t = Date.now()
                if (v.length < 2 || isNaN(v[0])) return
                if (root.lastNet) {
                    const dt = (t - root.lastNet.t) / 1000
                    if (dt > 0) { root.rxRate = Math.max(0, (v[0] - root.lastNet.rx) / dt); root.txRate = Math.max(0, (v[1] - root.lastNet.tx) / dt) }
                }
                root.lastNet = { rx: v[0], tx: v[1], t: t }
            }
        }
    }
    function setProfile(p, undo) {
        if (ppSet.running || p === profile) return
        ppPrev = undo ? "" : profile
        profile = p
        ppSet.command = ["powerprofilesctl", "set", p]
        ppSet.running = true
    }

    // Qué apps usan más CPU/memoria: solo se mide mientras el mouse está sobre un anillo.
    property bool procWanted: false
    property var topCpu: []
    property var topMem: []
    Timer { interval: 2500; repeat: true; triggeredOnStart: true; running: root.open && root.procWanted; onTriggered: if (!procs.running) procs.running = true }
    Process {
        id: procs
        command: [Qt.resolvedUrl("../scripts/top-procs.sh").toString().replace("file://", "")]
        stdout: StdioCollector {
            onStreamFinished: {
                const c = [], m = []
                for (const l of text.trim().split("\n")) {
                    const f = l.split(" ")
                    if (f.length < 3) continue
                    if (f[0] === "C") c.push(f[1] + " " + f[2] + "%")
                    else if (f[0] === "M") m.push(f[1] + " " + root.mb(Number(f[2])))
                }
                root.topCpu = c; root.topMem = m
            }
        }
    }
    // Aviso breve bajo Recursos (p. ej. si no hay monitor del sistema instalado).
    property string toast: Launch.error
    Timer { id: toastT; interval: 3500; onTriggered: root.toast = Qt.binding(() => Launch.error) }
    function showToast(t) { toast = t; toastT.restart() }
    Process {
        id: monProc
        command: [Qt.resolvedUrl("../scripts/open-monitor.sh").toString().replace("file://", "")]
        onExited: code => { if (code !== 0) root.showToast(I18n.tr("No hay un monitor del sistema instalado")) }
    }
    function openMonitor() { if (!monProc.running) monProc.running = true }
    // Lleva a la vista lo que recibe el foco con Tab (si el panel está desplazado).
    function ensureVisible(it) {
        if (!it || !flick.interactive) return
        const p = it.mapToItem(flick.contentItem, 0, 0)
        let to = flick.contentY
        if (p.y < flick.contentY + 16) to = p.y - 16
        else if (p.y + it.height > flick.contentY + flick.height - 16) to = p.y + it.height - flick.height + 16
        scrollTo(to)
    }
    function scrollTo(y) {
        scrollAnim.to = Math.max(0, Math.min(flick.contentHeight - flick.height, y)); scrollAnim.restart()
    }

    readonly property var r: SysStatus.res
    readonly property var n: SysStatus.net
    readonly property var d: SysStatus.dev
    readonly property var bat: r ? r.battery : null
    function batText(b) {
        if (!b) return ""
        const t = b.mins === null || b.mins === undefined ? "" : " · " + (b.mins >= 60 ? Math.floor(b.mins / 60) + " h " : "") + (b.mins % 60) + " min"
        return b.pct + "%" + (b.status === "Charging" ? I18n.tr(" · Cargando") + t
                            : b.status === "Full" ? I18n.tr(" · Cargada")
                            : b.status === "Not charging" ? I18n.tr(" · Enchufada") : t)
    }

    component Title: Text {
        color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold
        font.letterSpacing: 0.2; leftPadding: 16
    }
    component Row2: Item {
        id: rw
        property string icon
        property string label
        property string value
        property color valueColor: Theme.textSecondary
        width: parent ? parent.width : 0; height: 40
        Icon { x: 16; anchors.verticalCenter: parent.verticalCenter; name: rw.icon; size: 16; tone: "dark" }
        Text {
            x: 44; anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.5 - 44
            text: rw.label; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13; elide: Text.ElideRight
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.5 - 14; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
            text: rw.value; color: rw.valueColor; font.family: Theme.font; font.pixelSize: 12; font.features: { "tnum": 1 }
        }
    }
    component Card: Rectangle {
        default property alias content: inner.children
        width: parent ? parent.width : 0; height: inner.implicitHeight + 8
        radius: 18; color: Theme.surface
        Column { id: inner; y: 4; width: parent.width }
    }
    component Bar: Item {
        id: br
        property real frac: 0
        property bool lowIsBad: false       // batería: rojo cuando queda poco
        readonly property bool bad: lowIsBad ? frac < 0.15 : frac > 0.9
        width: parent ? parent.width - 28 : 0; x: 14; height: 10
        Rectangle {
            anchors.top: parent.top; width: parent.width; height: 4; radius: 2; color: Theme.track
            Rectangle {
                height: parent.height; radius: 2; color: br.bad ? Theme.danger : Theme.fill
                width: parent.width * Math.max(0, Math.min(1, br.frac))
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
    }

    // Anillo grande para las métricas principales; el número se anima.
    component Gauge: Item {
        id: g
        property real frac: 0
        property bool bad: false
        property string label
        property string detail
        property string hoverDetail
        property string tipTitle
        property string tipPrefix
        property var tipLines: []
        property bool hot: false          // detalle tras una pausa breve: no parpadea al cruzar
        signal activated()
        activeFocusOnTab: true
        Keys.onReturnPressed: g.activated()
        Keys.onSpacePressed: g.activated()
        onActiveFocusChanged: { g.hot = activeFocus; if (activeFocus) root.ensureVisible(g) }
        Timer { id: gHot; interval: Theme.durHover; onTriggered: g.hot = true }
        z: hot ? 5 : 0
        property real shown: Math.max(0, Math.min(1, frac))
        Behavior on shown { NumberAnimation { duration: 900; easing.type: Easing.OutQuart } }   // cifras que se deslizan, no saltan
        onShownChanged: cv.requestPaint()
        onBadChanged: cv.requestPaint()
        height: 136
        Item {
            id: ring
            width: 88; height: 88; anchors.horizontalCenter: parent.horizontalCenter; y: 4
            scale: gm.pressed ? 0.97 : gh.hovered ? 1.02 : 1
            Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
            Canvas {
                id: cv
                anchors.fill: parent; renderStrategy: Canvas.Cooperative
                onPaint: {
                    const c = getContext("2d"), w = 6, rr = width / 2 - w / 2
                    c.reset(); c.lineCap = "round"; c.lineWidth = w
                    c.strokeStyle = String(Theme.track)
                    c.beginPath(); c.arc(width / 2, height / 2, rr, 0, 2 * Math.PI); c.stroke()
                    if (g.shown > 0.005) {
                        c.strokeStyle = String(g.bad ? Theme.danger : Theme.fill)
                        c.beginPath(); c.arc(width / 2, height / 2, rr, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * g.shown); c.stroke()
                    }
                }
            }
            Row {
                anchors.centerIn: parent
                Text {
                    text: Math.round(g.shown * 100); color: g.bad ? Theme.danger : Theme.textPrimary
                    font.family: Theme.font; font.pixelSize: 26; font.weight: Font.Medium; font.features: { "tnum": 1 }
                }
                Text {
                    text: "%"; anchors.baseline: parent.children[0].baseline; color: Theme.textSecondary
                    font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter; y: 100
            text: g.label; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter; y: 120; width: parent.width - 8
            horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
            // En reposo solo el nombre; el detalle aparece al pasar el mouse o si hay alerta.
            // Al pasar el mouse, en la misma línea: lo que más usa ahora (sin globos que tapen filas).
            text: g.hot ? (g.tipLines.length ? (g.tipPrefix !== "" ? g.tipPrefix + " · " : "") + g.tipLines.slice(0, g.tipPrefix !== "" ? 1 : 2).join(" · ") : g.hoverDetail)
                : g.bad ? g.detail : ""
            opacity: text !== "" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durNormal } }
            color: g.bad ? Theme.danger : Theme.textSecondary
            font.family: Theme.font; font.pixelSize: 11; font.features: { "tnum": 1 }
        }
        Rectangle {      // foco con teclado
            anchors.fill: ring; anchors.margins: -5; radius: width / 2
            color: "transparent"; border.width: 2; border.color: Theme.fill
            opacity: g.activeFocus ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        }
        // Globo con las apps que más usan este recurso ahora mismo.
        Rectangle {
            id: tip
            readonly property bool want: false
            anchors.horizontalCenter: parent.horizontalCenter; y: 128
            width: Math.max(140, tipCol.implicitWidth + 24); height: tipCol.implicitHeight + 16; radius: 12
            color: Theme.fill
            opacity: want ? 1 : 0; visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            Column {
                id: tipCol; x: 12; y: 8; spacing: 2
                Text { text: g.tipTitle; color: Theme.onAccent; opacity: 0.7; font.family: Theme.font; font.pixelSize: 11 }
                Repeater {
                    model: g.tipLines
                    Text { required property var modelData; text: modelData; color: Theme.onAccent; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium; font.features: { "tnum": 1 } }
                }
                Text { text: I18n.tr("Clic: abrir monitor del sistema"); color: Theme.onAccent; opacity: 0.7; font.family: Theme.font; font.pixelSize: 11; topPadding: 2 }
            }
        }
        // Solo el anillo y sus textos cuentan como "encima": el globo no retiene el hover.
        Item { width: parent.width; height: 136
        HoverHandler { id: gh; onHoveredChanged: hovered ? gHot.restart() : (gHot.stop(), g.hot = g.activeFocus) } }
        MouseArea { id: gm; anchors.fill: ring; cursorShape: Qt.PointingHandCursor; onClicked: g.activated() }
    }
    // Fila compacta: icono, nombre, valor y barra fina debajo. Al pasar el mouse, más detalle.
    component MiniRow: Item {
        id: mr
        property string icon
        property string label
        property string value
        property string hoverValue
        property real frac: 0
        property bool lowIsBad: false
        property bool bad: lowIsBad ? frac < 0.15 : frac > 0.9
        property bool clickable: false
        property string hint             // texto extra al pasar el mouse si se puede tocar
        signal activated()
        property bool hot: false
        Timer { id: mHot; interval: Theme.durHover; onTriggered: mr.hot = true }
        activeFocusOnTab: clickable
        Keys.onReturnPressed: mr.activated()
        Keys.onSpacePressed: mr.activated()
        onActiveFocusChanged: { mr.hot = activeFocus; if (activeFocus) root.ensureVisible(mr) }
        width: parent ? parent.width : 0; height: 40
        Rectangle {
            anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4; radius: 14
            color: mh.hovered ? Theme.hover : "transparent"
            scale: mrm.pressed ? 0.98 : 1
            border.width: mr.activeFocus ? 2 : 0; border.color: Theme.fill
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
            Behavior on scale { NumberAnimation { duration: 120 } }
        }
        Icon { x: 16; y: 7; name: mr.icon; size: 16; tone: "dark" }
        Text {
            x: 44; y: 6; text: mr.label; color: Theme.textPrimary
            font.family: Theme.font; font.pixelSize: 13
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 16; y: 7; width: parent.width - 130
            horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
            text: mr.hot && mr.hoverValue !== "" ? mr.hoverValue + (mr.clickable && mr.hint !== "" ? " · " + mr.hint : "") : mr.value
            color: mr.bad ? Theme.danger : Theme.textSecondary
            font.family: Theme.font; font.pixelSize: 12; font.features: { "tnum": 1 }
        }
        Rectangle {
            x: 44; y: 28; width: parent.width - 60; height: 3; radius: 1.5; color: Theme.track
            Rectangle {
                height: parent.height; radius: 2; color: mr.bad ? Theme.danger : Theme.fill
                width: parent.width * Math.max(0, Math.min(1, mr.frac))
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
        HoverHandler { id: mh; onHoveredChanged: hovered ? mHot.restart() : (mHot.stop(), mr.hot = mr.activeFocus) }
        MouseArea { id: mrm; anchors.fill: parent; enabled: mr.clickable; cursorShape: Qt.PointingHandCursor; onClicked: mr.activated() }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width; contentHeight: root.implicitHeight
        interactive: contentHeight > height + 1
        clip: true; boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 2600; maximumFlickVelocity: 2200
        NumberAnimation { id: scrollAnim; target: flick; property: "contentY"; duration: 260; easing.type: Easing.OutCubic }
        // Rueda del mouse: pasos suaves animados en vez de saltos.
        WheelHandler {
            enabled: flick.interactive
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: e => {
                const base = scrollAnim.running ? scrollAnim.to : flick.contentY
                const dy = e.pixelDelta.y !== 0 ? -e.pixelDelta.y : -e.angleDelta.y / 120 * 90
                if (e.pixelDelta.y !== 0) { scrollAnim.stop(); flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + dy)) }
                else root.scrollTo(base + dy)
            }
        }
    Column {
        id: col
        x: 16; y: 16; width: flick.width - 32
        spacing: 8

        // Personaje: sigue el mouse solo con el panel abierto (activo = visible).
        Item {
            width: parent.width; height: 64
            Character {
                id: chr
                size: 60
                anchors.centerIn: parent
                active: root.open && DisplayState.characterAnimated
                mood: root.mood
                // Clic → reacción; varios clics seguidos → caricias.
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: m => chr.clicked((m.x - width / 2) / (width / 2)) }
            }
        }

        // Internet: estado de la conexión y, si hay placa Wi-Fi, el control de Wi-Fi con la
        // lista de redes (antes en el menú de la isla) justo debajo.
        Title { text: "Internet" }
        // Con Wi-Fi y todo bien, la fila de Wi-Fi ya lo dice: la de estado solo aparece con
        // cable, sin conexión o con un problema (sin internet, portal).
        Card {
            visible: !(root.n && root.n.type === "wifi" && Network.hasWifi && SysStatus.online)
            Row2 {
                icon: root.n && root.n.type === "wifi" ? "wifi" : "ethernet"
                label: !root.n || !root.n.type ? I18n.tr("Sin conexión") : (root.n.type === "wifi" ? "Internet" : "Ethernet")
                value: !SysStatus.known ? I18n.tr("Comprobando…")
                     : SysStatus.online ? I18n.tr("Conectado")
                     : SysStatus.connectivity === "portal" ? I18n.tr("Requiere inicio de sesión")
                     : SysStatus.connectivity === "limited" ? I18n.tr("Sin internet (red limitada)") : I18n.tr("Sin internet")
                valueColor: SysStatus.known && !SysStatus.online ? Theme.danger : Theme.textSecondary
            }
        }
        WifiSection { id: wifiSec; width: parent.width; active: root.open }

        // Recursos: lo más importante (CPU y memoria) en dos anillos grandes; disco, batería y
        // GPU en filas compactas. Los números se animan; al pasar el mouse muestran más detalle.
        Card {
            // Wi-Fi (solo si hay placa inalámbrica y conexión): red, señal y velocidad.
            // Clic → abre la lista de redes de arriba.
            Item {
                id: wr
                visible: Network.hasWifi && Network.wifiEnabled && Network.ssid !== ""
                width: parent.width; height: 40
                activeFocusOnTab: visible
                property bool hot: false
                Timer { id: wHot; interval: Theme.durHover; onTriggered: wr.hot = true }
                onActiveFocusChanged: { wr.hot = activeFocus; if (activeFocus) root.ensureVisible(wr) }
                Keys.onReturnPressed: wr.activate()
                Keys.onSpacePressed: wr.activate()
                function activate() {
                    wifiSec.expanded = true; Network.scan()
                    root.scrollTo(wifiSec.mapToItem(flick.contentItem, 0, 0).y - 40)   // que se vea la lista
                }
                readonly property string quality: Network.signal >= 70 ? I18n.tr("Excelente") : Network.signal >= 45 ? I18n.tr("Buena")
                                                : Network.signal >= 25 ? I18n.tr("Débil") : I18n.tr("Muy débil")
                Rectangle {
                    anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4; radius: 14
                    color: wh.hovered ? Theme.hover : "transparent"
                    scale: wm.pressed ? 0.98 : 1
                    border.width: wr.activeFocus ? 2 : 0; border.color: Theme.fill
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    Behavior on scale { NumberAnimation { duration: 120 } }
                }
                // El nombre de la red ya está arriba: aquí solo el tráfico (si lo hay) o la calidad.
                readonly property bool busy: root.rxRate >= 65536 || root.txRate >= 65536
                Icon { x: 16; anchors.verticalCenter: parent.verticalCenter; name: "wifi"; size: 16; tone: "dark" }
                Text {
                    x: 44; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 100; elide: Text.ElideRight
                    text: wr.hot ? I18n.tr("Señal %1% · ver redes", Network.signal)
                        : wr.busy ? "↓ " + root.rate(root.rxRate) + "   ↑ " + root.rate(root.txRate) : wr.quality
                    color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12; font.features: { "tnum": 1 }
                }
                HoverHandler { id: wh; onHoveredChanged: hovered ? wHot.restart() : (wHot.stop(), wr.hot = wr.activeFocus) }
                MouseArea { id: wm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wr.activate() }
            }
            Item {
                width: parent.width; height: 136
                z: cpuG.hot || memG.hot ? 5 : 0       // el globo queda por encima de las filas
                Row {
                    anchors.centerIn: parent; spacing: 0
                    Gauge {
                        id: cpuG
                        width: (parent.parent.width) / 2
                        frac: root.r ? root.r.cpu / 100 : 0
                        bad: root.r ? (root.r.cpu > 85 || (root.r.temp !== null && root.r.temp !== undefined && root.r.temp >= 85)) : false
                        label: "CPU"
                        // En alerta, la línea explica por qué está en rojo.
                        detail: !root.r ? "…" : root.r.cpu > 85 ? I18n.tr("Uso alto")
                              : root.r.temp !== null && root.r.temp !== undefined && root.r.temp >= 85 ? I18n.tr("Calor: %1 °C", root.r.temp)
                              : root.r.temp !== null && root.r.temp !== undefined ? root.r.temp + " °C" : I18n.tr("En uso")
                        hoverDetail: !root.r || root.r.temp === null || root.r.temp === undefined ? I18n.tr("Uso del procesador")
                                   : root.r.temp >= 85 ? I18n.tr("Temperatura alta") : I18n.tr("Temperatura normal")
                        tipTitle: I18n.tr("Más uso ahora"); tipLines: root.topCpu
                        tipPrefix: root.r && root.r.temp !== null && root.r.temp !== undefined ? root.r.temp + " °C" : ""
                        onHotChanged: root.procWanted = hot || memG.hot
                        onActivated: root.openMonitor()
                    }
                    Gauge {
                        id: memG
                        width: (parent.parent.width) / 2
                        frac: root.r ? root.r.memUsed / root.r.memTotal : 0
                        bad: root.r ? root.r.memUsed / root.r.memTotal > 0.9 : false
                        tipTitle: I18n.tr("Más memoria"); tipLines: root.topMem
                        onHotChanged: root.procWanted = hot || cpuG.hot
                        onActivated: root.openMonitor()
                        label: I18n.tr("Memoria")
                        detail: !root.r ? "…" : root.r.memUsed / root.r.memTotal > 0.9 ? I18n.tr("Casi llena")
                              : I18n.tr("%1 de %2 GB", SysStatus.gib(root.r.memUsed), SysStatus.gib(root.r.memTotal))
                        hoverDetail: root.r ? I18n.tr("%1 GB libres", SysStatus.gib(root.r.memTotal - root.r.memUsed)) : "…"
                    }
                }
            }
            MiniRow {
                icon: "folder"; label: I18n.tr("Disco")
                frac: root.r ? root.r.diskUsed / root.r.diskTotal : 0
                value: root.r ? I18n.tr("%1 GB libres", SysStatus.gib(root.r.diskTotal - root.r.diskUsed)) : "…"
                hoverValue: root.r ? I18n.tr("%1 de %2 GB", SysStatus.gib(root.r.diskUsed), SysStatus.gib(root.r.diskTotal)) : "…"
                clickable: true; hint: I18n.tr("abrir")
                onActivated: Launch.open("files")
            }
            MiniRow {
                visible: !!root.bat
                icon: "battery"; label: I18n.tr("Batería"); lowIsBad: true
                frac: root.bat ? root.bat.pct / 100 : 0
                value: root.bat ? root.bat.pct + "%" : ""
                hoverValue: root.batText(root.bat)
                bad: !!root.bat && root.bat.pct < 15 && root.bat.status === "Discharging"
            }
            // Batería baja: sugerencia de un toque para pasar a Ahorro (y volver con Deshacer).
            Item {
                id: lowBat
                visible: !!root.bat && root.bat.pct <= 20 && root.bat.status === "Discharging"
                         && root.profile !== "" && (root.profile !== "power-saver" || root.ppApplied !== "")
                readonly property bool done: root.profile === "power-saver"     // queda unos segundos: sin saltos
                width: parent.width; height: 34
                Rectangle {
                    x: 44; anchors.verticalCenter: parent.verticalCenter
                    width: lbT.implicitWidth + 24; height: 26; radius: 13
                    color: lbM.containsMouse ? Theme.fillHover : Theme.fill
                    scale: lbM.pressed ? 0.96 : 1
                    border.width: lowBat.activeFocus ? 2 : 0; border.color: Theme.textSecondary
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Text { id: lbT; anchors.centerIn: parent; text: lowBat.done ? I18n.tr("Ahorro activado") : I18n.tr("Batería baja · usar Ahorro"); color: Theme.onAccent; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                    MouseArea { id: lbM; anchors.fill: parent; hoverEnabled: true; enabled: !lowBat.done; cursorShape: Qt.PointingHandCursor; onClicked: root.setProfile("power-saver") }
                }
                activeFocusOnTab: visible
                Keys.onReturnPressed: root.setProfile("power-saver")
                Keys.onSpacePressed: root.setProfile("power-saver")
                onActiveFocusChanged: if (activeFocus) root.ensureVisible(lowBat)
            }
            MiniRow {
                visible: !!SysStatus.gpu
                icon: "display"; label: "GPU"
                frac: SysStatus.gpu ? SysStatus.gpu.util / 100 : 0
                value: SysStatus.gpu ? SysStatus.gpu.util + "%" : ""
                hoverValue: SysStatus.gpu ? SysStatus.gpu.temp + " °C · " + SysStatus.gpu.name : ""
            }
        }

        Text {
            visible: root.toast !== ""
            width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
            text: root.toast; color: Theme.danger; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium
        }
        // Modo de energía: control segmentado. La pastilla negra se desliza a la opción elegida;
        // al pasar el mouse la línea de abajo anticipa qué hace cada modo y, al aplicarlo, lo confirma.
        Item {
            id: seg
            visible: root.profile !== ""
            width: parent.width; height: 40
            property int hoverIdx: -1
            readonly property var modes: [{ id: "power-saver", label: I18n.tr("Ahorro"), desc: I18n.tr("Más batería, menos rendimiento") },
                                          { id: "balanced", label: I18n.tr("Equilibrado"), desc: I18n.tr("Equilibrio entre rendimiento y batería") },
                                          { id: "performance", label: I18n.tr("Rendimiento"), desc: I18n.tr("Máxima velocidad, más consumo") }]
            readonly property int idx: { for (let i = 0; i < modes.length; i++) if (modes[i].id === root.profile) return i; return -1 }
            Rectangle { anchors.fill: parent; radius: height / 2; color: Theme.track }
            Rectangle {      // pastilla elegida: se desliza y late suave mientras se aplica
                id: thumb
                visible: seg.idx >= 0
                y: 4; height: parent.height - 8; width: (parent.width - 8) / 3; radius: height / 2
                x: 4 + Math.max(0, seg.idx) * width; color: Theme.fill
                scale: seg.pressedIdx === seg.idx && seg.idx >= 0 ? 0.96 : 1
                Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 120 } }
                SequentialAnimation on opacity {
                    running: ppSet.running; loops: Animation.Infinite
                    onRunningChanged: if (!running) thumb.opacity = 1
                    NumberAnimation { to: 0.7; duration: 350 } NumberAnimation { to: 1; duration: 350 }
                }
            }
            property int pressedIdx: -1
            Row {
                anchors.fill: parent; anchors.margins: 4
                Repeater {
                    model: seg.modes
                    Item {
                        id: pp
                        required property var modelData
                        required property int index
                        readonly property bool sel: seg.idx === index
                        width: parent.width / 3; height: parent.height
                        activeFocusOnTab: true
                        Keys.onReturnPressed: root.setProfile(modelData.id)
                        Keys.onSpacePressed: root.setProfile(modelData.id)
                        Keys.onLeftPressed: if (index > 0) root.setProfile(seg.modes[index - 1].id)
                        Keys.onRightPressed: if (index < 2) root.setProfile(seg.modes[index + 1].id)
                        onActiveFocusChanged: seg.hoverIdx = activeFocus ? index : -1
                        Rectangle {
                            anchors.fill: parent; radius: height / 2
                            color: !pp.sel && ppm.containsMouse ? Theme.hover : "transparent"
                            scale: ppm.pressed && !pp.sel ? 0.95 : 1
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                            Behavior on scale { NumberAnimation { duration: 120 } }
                        }
                        Rectangle {
                            anchors.fill: parent; anchors.margins: -2; radius: height / 2
                            color: "transparent"; border.width: 2; border.color: Theme.fill
                            opacity: pp.activeFocus ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                        }
                        Text {
                            anchors.centerIn: parent; text: pp.modelData.label
                            color: pp.sel ? Theme.onAccent : (ppm.containsMouse ? Theme.textPrimary : Theme.textSecondary)
                            font.family: Theme.font; font.pixelSize: 12; font.weight: pp.sel ? Font.DemiBold : Font.Medium
                            Behavior on color { ColorAnimation { duration: Theme.durNormal } }
                        }
                        MouseArea {
                            id: ppm; anchors.fill: parent; hoverEnabled: true; cursorShape: pp.sel ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onContainsMouseChanged: seg.hoverIdx = containsMouse ? pp.index : (seg.hoverIdx === pp.index ? -1 : seg.hoverIdx)
                            onPressedChanged: seg.pressedIdx = pressed ? pp.index : -1
                            onClicked: root.setProfile(pp.modelData.id)
                        }
                    }
                }
            }
        }
        Item {
            visible: seg.visible && seg.idx >= 0
            width: parent.width; height: 12      // reservado: el texto aparece sin mover nada
        Text {
            id: segDesc
            width: parent.width - (undo.visible ? undo.width + 8 : 0); horizontalAlignment: undo.visible ? Text.AlignRight : Text.AlignHCenter; elide: Text.ElideRight
            readonly property bool preview: seg.hoverIdx >= 0 && seg.hoverIdx !== seg.idx
            text: root.ppApplied !== "" ? I18n.tr("Modo %1 activado", root.ppApplied)
                : preview ? seg.modes[seg.hoverIdx].label + ": " + seg.modes[seg.hoverIdx].desc
                : ""
            color: root.ppApplied !== "" || preview ? Theme.textPrimary : Theme.textSecondary
            font.family: Theme.font; font.pixelSize: 11; font.weight: root.ppApplied !== "" ? Font.DemiBold : Font.Normal
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
        }
        // Deshacer: vuelve al modo anterior durante unos segundos.
        Text {
            id: undo
            visible: root.ppApplied !== "" && root.ppPrev !== ""
            anchors.left: segDesc.right; anchors.leftMargin: 8
            text: I18n.tr("Deshacer"); color: Theme.textPrimary
            font.family: Theme.font; font.pixelSize: 11; font.weight: Font.Bold; font.underline: um.containsMouse
            MouseArea { id: um; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { const p = root.ppPrev; root.ppApplied = ""; root.setProfile(p, true) } }
        }
        }

        // Liberar memoria: barra-botón de 48 px con cuatro estados claros.
        //  · Reposo: el relleno es la RAM en uso; dice cuánto se usa.
        //  · Armado (1.er clic): toda negra, "Confirmar" y un anillo que descuenta los 3 s.
        //  · Liberando: un brillo recorre la barra.
        //  · Listo: icono de check, el relleno baja animado y el resultado queda debajo.
        Item {
            width: parent.width; height: freeBar.height + (freeText.visible ? freeText.height + 8 : 0)
            Behavior on height { NumberAnimation { duration: Theme.durFast } }
            Item {
                id: freeBar
                width: parent.width; height: 44
                activeFocusOnTab: true
                readonly property bool busy: freeProc.running
                readonly property bool dark: root.freeArmed || busy
                readonly property real frac: dark ? 1 : 0     // la RAM ya está en el anillo: en reposo es un botón limpio
                property real ramShown: root.r ? 100 * root.r.memUsed / root.r.memTotal : 0
                Behavior on ramShown { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
                Keys.onReturnPressed: root.pressFree()
                Keys.onSpacePressed: root.pressFree()
                onActiveFocusChanged: if (activeFocus) root.ensureVisible(freeBar)
                Keys.onEscapePressed: event => { if (root.freeArmed) { root.freeArmed = false; event.accepted = true } else event.accepted = false }
                Rectangle {
                    id: freeBg
                    anchors.fill: parent; radius: height / 2; clip: true
                    color: freeMouse.containsMouse && !freeBar.dark ? Theme.hover : Theme.track
                    scale: freeMouse.pressed ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    Rectangle {
                        id: freeFill
                        height: parent.height; radius: height / 2; color: freeMouse.pressed ? Theme.fillHover : Theme.fill
                        width: freeBar.frac > 0 ? parent.width : 0
                        opacity: freeBar.frac > 0 ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.durNormal } }
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Rectangle {      // brillo mientras libera
                        visible: freeBar.busy
                        width: 90; height: parent.height; color: Theme.onAccent; opacity: 0.10; radius: height / 2
                        NumberAnimation on x { running: freeBar.busy; loops: Animation.Infinite; from: -90; to: freeBar.width; duration: 1500; easing.type: Easing.InOutSine }
                    }
                }
                Rectangle {
                    anchors.fill: parent; anchors.margins: -4; radius: height / 2
                    color: "transparent"; border.width: 2; border.color: Theme.fill
                    opacity: freeBar.activeFocus ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                }
                Icon {
                    x: 16; anchors.verticalCenter: parent.verticalCenter
                    size: 18; name: root.freeDone ? "check" : "apps"; tone: freeFill.width > 40 ? "white" : "dark"
                    scale: root.freeDone ? 1.1 : 1
                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                }
                Column {
                    x: 50; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 120; spacing: 1
                    Text {
                        id: freeLbl
                        width: parent.width; elide: Text.ElideRight
                        text: root.freeArmed ? (root.freeCount > 0 ? I18n.tr("Confirmar: cerrar %1", root.freeCount) : I18n.tr("Confirmar")) : freeBar.busy ? I18n.tr("Liberando…")
                            : root.freeDone ? I18n.tr("Listo") : I18n.tr("Liberar memoria")
                        color: freeBar.dark || freeFill.width > 50 + Math.min(width, implicitWidth) * 0.6 ? Theme.onAccent : Theme.textPrimary
                        font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    }
                    Text {
                        width: parent.width; elide: Text.ElideRight
                        text: root.freeArmed ? root.freePreview
                            : freeBar.busy ? I18n.tr("Cerrando ventanas sin forzar")
                            : root.freeMsg !== "" ? root.freeMsg        // resultado dentro del botón: sin línea extra
                            : !root.r ? "" : root.r.memUsed / root.r.memTotal > 0.9 ? I18n.tr("Memoria casi llena: conviene liberar") : ""
                        visible: text !== ""
                        color: freeBar.dark || freeFill.width > 50 + Math.min(width, implicitWidth) * 0.6 ? Theme.onAccent : Theme.textSecondary
                        opacity: 0.8; font.family: Theme.font; font.pixelSize: 11; font.features: { "tnum": 1 }
                    }
                }
                // Derecha: % de RAM en reposo; anillo con los segundos que quedan al armar.
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
                    visible: false
                    text: Math.round(freeBar.ramShown) + "%"
                    color: freeFill.width > freeBar.width - 60 ? Theme.onAccent : Theme.textPrimary
                    font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold; font.features: { "tnum": 1 }
                }
                Item {
                    id: countdown
                    visible: root.freeArmed
                    width: 26; height: 26
                    anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                    property real remain: 1
                    NumberAnimation on remain { running: root.freeArmed; from: 1; to: 0; duration: 4000 }
                    onRemainChanged: cdc.requestPaint()
                    Canvas {
                        id: cdc; anchors.fill: parent; renderStrategy: Canvas.Cooperative
                        onPaint: {
                            const c = getContext("2d"); c.reset(); c.lineWidth = 2; c.lineCap = "round"
                            c.strokeStyle = String(Theme.onAccent)
                            c.globalAlpha = 0.3; c.beginPath(); c.arc(13, 13, 11, 0, 2 * Math.PI); c.stroke()
                            c.globalAlpha = 1; c.beginPath(); c.arc(13, 13, 11, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * countdown.remain); c.stroke()
                        }
                    }
                    Text {
                        anchors.centerIn: parent; text: Math.ceil(countdown.remain * 4)
                        color: Theme.onAccent; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: freeMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: freeBar.busy ? Qt.BusyCursor : Qt.PointingHandCursor
                    onClicked: root.pressFree()
                }
            }
            Text {
                id: freeText
                visible: false
                anchors.top: freeBar.bottom; anchors.topMargin: 8; width: parent.width
                horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                text: root.freeMsg; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium
            }
        }

        // Dispositivos
        Title { text: I18n.tr("Dispositivos"); topPadding: 8 }
        Card {
            Repeater { model: root.d ? root.d.keyboards : []; Row2 { required property var modelData; icon: "keyboard"; label: I18n.tr("Teclado"); value: modelData } }
            Repeater { model: root.d ? root.d.mice : []; Row2 { required property var modelData; icon: "mouse"; label: I18n.tr("Mouse"); value: modelData } }
            Row2 { visible: !!(root.d && root.d.audio); icon: "volume"; label: "Audio"; value: root.d ? root.d.audio : "" }
            Repeater { model: root.d ? root.d.bluetooth : []; Row2 { required property var modelData; icon: "bluetooth"; label: "Bluetooth"; value: modelData } }
            Repeater { model: root.d ? root.d.usb : []; Row2 { required property var modelData; icon: "usb"; label: "USB"; value: modelData } }
            Row2 { visible: !root.d; icon: "info"; label: I18n.tr("Buscando…"); value: "" }
        }
    }
    }
    // Bordes difuminados: indican que hay más contenido arriba o abajo.
    Rectangle {
        anchors.top: parent.top; width: parent.width; height: 28
        opacity: flick.interactive && flick.contentY > 2 ? 1 : 0; visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        gradient: Gradient { GradientStop { position: 0; color: Theme.card } GradientStop { position: 1; color: Qt.rgba(Theme.card.r, Theme.card.g, Theme.card.b, 0) } }
    }
    Rectangle {
        anchors.bottom: parent.bottom; width: parent.width; height: 36
        opacity: flick.interactive && flick.contentY < flick.contentHeight - flick.height - 2 ? 1 : 0; visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        gradient: Gradient { GradientStop { position: 0; color: Qt.rgba(Theme.card.r, Theme.card.g, Theme.card.b, 0) } GradientStop { position: 1; color: Theme.card } }
    }
}
