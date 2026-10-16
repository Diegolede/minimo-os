// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import "../Common"
import "../Character"

// Minimo como mascota (se abre deslizando hacia abajo sobre la isla).
// Comida, ánimo y energía; la energía refleja tus pausas frente a la PC.
Item {
    id: root
    property bool open: false
    signal done()
    implicitHeight: col.implicitHeight + 40

    onOpenChanged: {
        open ? Pet.acquire() : Pet.release()
        if (open) greetLater.restart()
    }
    Component.onDestruction: if (open) Pet.release()
    Timer { id: greetLater; interval: 280; onTriggered: chr.react(Pet.mood === "" ? "wink" : "curious") }
    // Dormir: cierra la isla y duerme recién después, para que se vea en la isla compacta.
    Timer { id: napLater; interval: 350; onTriggered: IdleState.sleepNow() }

    readonly property string line: {
        if (Pet.energy < 0.25) return "Llevás " + root.duration(Pet.activeMinutes) + " sin pausa. ¿Un descanso?"
        if (Pet.food < 0.25) return "Tiene hambre."
        if (Pet.fun < 0.2) return "Se aburre. ¿Jugamos?"
        if (Pet.energy < 0.5) return "Empieza a tener sueño."
        return "Está contento."
    }
    function duration(m) { return m >= 60 ? Math.floor(m / 60) + " h" + (m % 60 ? " " + (m % 60) + " min" : "") : m + " min" }

    Column {
        id: col
        x: 20; y: 20
        width: parent.width - 40
        spacing: 16

        Column {
            width: parent.width
            spacing: 10
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 96; height: 92
                Character {
                    id: chr
                    size: 76; anchors.centerIn: parent
                    active: root.open && DisplayState.characterAnimated
                    mood: Pet.mood
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: m => chr.clicked((m.x - width / 2) / (width / 2)) }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Minimo"
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 17; font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: root.line
                color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 13
            }
        }

        Rectangle {
            width: parent.width; height: meters.implicitHeight + 8; radius: 18; color: Theme.surface; border.width: 1; border.color: Theme.track
            Column {
                id: meters
                y: 4; width: parent.width
                PetMeter { width: parent.width; icon: "bowl"; label: "Comida"; frac: Pet.food }
                PetMeter { width: parent.width; icon: "ball"; label: "Ánimo"; frac: Pet.fun }
                PetMeter { width: parent.width; icon: "moon"; label: "Energía"; frac: Pet.energy }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            MenuButton { icon: "bowl"; label: "Comer"; onActivated: { Pet.feed(); chr.react("chew") } }
            MenuButton { icon: "ball"; label: "Jugar"; onActivated: { Pet.play(); chr.playGame() } }
            MenuButton { icon: "moon"; label: "Dormir"; onActivated: { root.done(); napLater.restart() } }
        }
    }
}
