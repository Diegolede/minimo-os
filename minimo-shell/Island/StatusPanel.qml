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

    onOpenChanged: {
        if (!open) { freeArmed = false; freeDisarm.stop() }
        open ? SysStatus.acquire() : SysStatus.release()
        if (open) greetLater.restart()
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
    function pressFree() {
        if (freeProc.running) return
        if (!freeArmed) { freeArmed = true; freeMsg = ""; freeDisarm.restart(); return }
        freeArmed = false; freeDisarm.stop()
        freeMsg = I18n.tr("Liberando…")
        freeProc.running = true
    }
    Timer { id: freeDisarm; interval: 3000; onTriggered: root.freeArmed = false }
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
            }
        }
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
        color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold
        leftPadding: 4
    }
    component Row2: Item {
        id: rw
        property string icon
        property string label
        property string value
        property color valueColor: Theme.textSecondary
        width: parent ? parent.width : 0; height: 40
        Icon { x: 14; anchors.verticalCenter: parent.verticalCenter; name: rw.icon; size: 18; tone: "dark" }
        Text {
            x: 44; anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.5 - 44
            text: rw.label; color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 14; elide: Text.ElideRight
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.5 - 14; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
            text: rw.value; color: rw.valueColor; font.family: Theme.font; font.pixelSize: 13; font.features: { "tnum": 1 }
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

    Column {
        id: col
        x: 16; y: 16; width: parent.width - 32
        spacing: 8

        // Personaje: sigue el mouse solo con el panel abierto (activo = visible).
        Item {
            width: parent.width; height: 76
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
        WifiSection { width: parent.width; active: root.open }

        // Recursos
        Title { text: I18n.tr("Recursos"); topPadding: 4 }
        Card {
            Row2 { icon: "chip"; label: "CPU"; value: root.r ? root.r.cpu + "%" + (root.r.temp !== null && root.r.temp !== undefined ? " · " + root.r.temp + " °C" : "") : "…" }
            Bar { frac: root.r ? root.r.cpu / 100 : 0 }
            Row2 { icon: "apps"; label: I18n.tr("Memoria"); value: root.r ? SysStatus.gib(root.r.memUsed) + " / " + SysStatus.gib(root.r.memTotal) + " GB" : "…" }
            Bar { frac: root.r ? root.r.memUsed / root.r.memTotal : 0 }
            Row2 { icon: "folder"; label: I18n.tr("Disco"); value: root.r ? Math.round(100 * root.r.diskUsed / root.r.diskTotal) + "% · " + SysStatus.gib(root.r.diskTotal - root.r.diskUsed) + " GB libres" : "…" }
            Bar { frac: root.r ? root.r.diskUsed / root.r.diskTotal : 0 }
            Row2 {
                visible: !!root.bat
                icon: "battery"; label: I18n.tr("Batería")
                value: root.batText(root.bat)
                valueColor: root.bat && root.bat.pct < 15 && root.bat.status === "Discharging" ? Theme.danger : Theme.textSecondary
            }
            Bar { visible: !!root.bat; frac: root.bat ? root.bat.pct / 100 : 0; lowIsBad: true }
            Row2 {
                visible: !!SysStatus.gpu
                icon: "display"; label: SysStatus.gpu ? SysStatus.gpu.name : "GPU"
                value: SysStatus.gpu ? SysStatus.gpu.util + "% · " + SysStatus.gpu.temp + " °C" : ""
            }
        }

        // Liberar memoria: barra con el mismo aspecto que los sliders (MSlider) pero que actúa
        // como botón. El relleno es el uso de RAM (datos del sondeo existente del panel); al
        // armar se pone toda negra con "Confirmar"; tras liberar, el relleno baja animado.
        Item {
            width: parent.width; height: freeBar.height + (freeText.visible ? freeText.height + 6 : 0)
            Item {
                id: freeBar
                width: parent.width; height: 40
                activeFocusOnTab: true
                readonly property real frac: root.freeArmed ? 1 : (root.r ? Math.max(0, Math.min(1, root.r.memUsed / root.r.memTotal)) : 0)
                Keys.onReturnPressed: root.pressFree()
                Keys.onSpacePressed: root.pressFree()
                Rectangle {
                    anchors.fill: parent; radius: height / 2; clip: true
                    color: freeMouse.containsMouse && !root.freeArmed ? Theme.hover : Theme.track
                    scale: freeMouse.pressed ? 0.98 : 1
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                    Rectangle {
                        id: freeFill
                        height: parent.height; radius: height / 2; color: Theme.fill
                        width: Math.max(parent.height, parent.width * freeBar.frac)
                        Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                    }
                }
                Rectangle {          // aro de foco por teclado (solo con foco)
                    anchors.fill: parent; anchors.margins: -4; radius: height / 2
                    color: "transparent"; border.width: 2; border.color: Theme.fill
                    visible: freeBar.activeFocus
                }
                Icon {
                    x: 12; anchors.verticalCenter: parent.verticalCenter
                    size: 18; name: "apps"; tone: freeFill.width > 36 ? "white" : "dark"
                }
                Text {
                    x: 50; anchors.verticalCenter: parent.verticalCenter
                    text: root.freeArmed ? I18n.tr("Confirmar") : freeProc.running ? I18n.tr("Liberando…") : I18n.tr("Liberar memoria")
                    color: freeFill.width > 140 ? Theme.onAccent : Theme.textPrimary
                    font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold
                }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                    visible: !root.freeArmed
                    text: root.r ? "RAM " + Math.round(100 * root.r.memUsed / root.r.memTotal) + "%" : ""
                    color: freeBar.frac > 0.85 ? Theme.onAccent : Theme.textSecondary
                    font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium; font.features: { "tnum": 1 }
                }
                MouseArea {
                    id: freeMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.pressFree()
                }
            }
            Text {
                id: freeText
                visible: root.freeMsg !== "" && !freeProc.running
                anchors.top: freeBar.bottom; anchors.topMargin: 6; width: parent.width
                horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                text: root.freeMsg; color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 12
            }
        }

        // Dispositivos
        Title { text: I18n.tr("Dispositivos"); topPadding: 4 }
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
