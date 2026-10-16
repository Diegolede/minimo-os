// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import "../Common"
import "../Character"
import "sections"

// Panel de estado del sistema (se abre deslizando sobre la isla): Internet, Recursos, Dispositivos.
// Consulta datos solo mientras está abierto.
Item {
    id: root
    property bool open: false
    implicitHeight: col.implicitHeight + 32

    onOpenChanged: {
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

    readonly property var r: SysStatus.res
    readonly property var n: SysStatus.net
    readonly property var d: SysStatus.dev
    readonly property var bat: r ? r.battery : null
    function batText(b) {
        if (!b) return ""
        const t = b.mins === null || b.mins === undefined ? "" : " · " + (b.mins >= 60 ? Math.floor(b.mins / 60) + " h " : "") + (b.mins % 60) + " min"
        return b.pct + "%" + (b.status === "Charging" ? " · Cargando" + t
                            : b.status === "Full" ? " · Cargada"
                            : b.status === "Not charging" ? " · Enchufada" : t)
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
        radius: 18; color: Theme.surface; border.width: 1; border.color: Theme.surfaceBorder
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
                label: !root.n || !root.n.type ? "Sin conexión" : (root.n.type === "wifi" ? "Internet" : "Ethernet")
                value: !SysStatus.known ? "Comprobando…"
                     : SysStatus.online ? "Conectado"
                     : SysStatus.connectivity === "portal" ? "Requiere inicio de sesión"
                     : SysStatus.connectivity === "limited" ? "Sin internet (red limitada)" : "Sin internet"
                valueColor: SysStatus.known && !SysStatus.online ? Theme.danger : Theme.textSecondary
            }
        }
        WifiSection { width: parent.width; active: root.open }

        // Recursos
        Title { text: "Recursos"; topPadding: 4 }
        Card {
            Row2 { icon: "chip"; label: "CPU"; value: root.r ? root.r.cpu + "%" + (root.r.temp !== null && root.r.temp !== undefined ? " · " + root.r.temp + " °C" : "") : "…" }
            Bar { frac: root.r ? root.r.cpu / 100 : 0 }
            Row2 { icon: "apps"; label: "Memoria"; value: root.r ? SysStatus.gib(root.r.memUsed) + " / " + SysStatus.gib(root.r.memTotal) + " GB" : "…" }
            Bar { frac: root.r ? root.r.memUsed / root.r.memTotal : 0 }
            Row2 { icon: "folder"; label: "Disco"; value: root.r ? Math.round(100 * root.r.diskUsed / root.r.diskTotal) + "% · " + SysStatus.gib(root.r.diskTotal - root.r.diskUsed) + " GB libres" : "…" }
            Bar { frac: root.r ? root.r.diskUsed / root.r.diskTotal : 0 }
            Row2 {
                visible: !!root.bat
                icon: "battery"; label: "Batería"
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

        // Dispositivos
        Title { text: "Dispositivos"; topPadding: 4 }
        Card {
            Repeater { model: root.d ? root.d.keyboards : []; Row2 { required property var modelData; icon: "keyboard"; label: "Teclado"; value: modelData } }
            Repeater { model: root.d ? root.d.mice : []; Row2 { required property var modelData; icon: "mouse"; label: "Mouse"; value: modelData } }
            Row2 { visible: !!(root.d && root.d.audio); icon: "volume"; label: "Audio"; value: root.d ? root.d.audio : "" }
            Repeater { model: root.d ? root.d.bluetooth : []; Row2 { required property var modelData; icon: "bluetooth"; label: "Bluetooth"; value: modelData } }
            Repeater { model: root.d ? root.d.usb : []; Row2 { required property var modelData; icon: "usb"; label: "USB"; value: modelData } }
            Row2 { visible: !root.d; icon: "info"; label: "Buscando…"; value: "" }
        }
    }
}
