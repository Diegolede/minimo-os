// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma ComponentBehavior: Bound
import QtQuick
import "../../Common"
import "../../Common/calendar.js" as Cal

// Calendario dentro de la isla (se abre con clic en la fecha): mes con hoy marcado,
// mes anterior/siguiente. Nombres y primer día de la semana según el idioma.
Item {
    id: root
    signal back()
    property date today: new Date()
    property var locale: Qt.locale()
    property int year: today.getFullYear()
    property int month: today.getMonth()
    implicitHeight: col.implicitHeight

    function reset() { year = today.getFullYear(); month = today.getMonth() }
    function shift(n) { const r = Cal.addMonths(year, month, n); year = r.y; month = r.m }
    readonly property int firstDay: locale.firstDayOfWeek % 7
    readonly property var cells: Cal.monthGrid(year, month, firstDay)
    readonly property string title: {
        const t = new Date(year, month, 1).toLocaleDateString(locale, "MMMM yyyy")
        return t.charAt(0).toUpperCase() + t.slice(1)
    }

    component RoundButton: Rectangle {
        id: rb
        property string icon
        property real iconRotation: 0
        signal clicked()
        width: 32; height: 32; radius: 16
        color: rbm.containsMouse ? Theme.hover : Theme.surface
        scale: rbm.pressed ? 0.9 : 1
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
        Icon { anchors.centerIn: parent; name: rb.icon; size: 18; rotation: rb.iconRotation }
        MouseArea { id: rbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rb.clicked() }
    }

    Column {
        id: col
        width: parent.width
        spacing: 14

        Item {
            width: parent.width; height: 32
            RoundButton { icon: "back"; onClicked: root.back() }
            Text {
                anchors.centerIn: parent
                text: root.title
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold
            }
            Row {
                anchors.right: parent.right
                spacing: 6
                RoundButton { icon: "chevron"; iconRotation: 90; onClicked: root.shift(-1) }
                RoundButton { icon: "chevron"; iconRotation: -90; onClicked: root.shift(1) }
            }
        }

        Grid {
            id: grid
            columns: 7
            width: parent.width
            readonly property real cw: width / 7
            Repeater {
                model: 7
                delegate: Text {
                    required property int index
                    width: grid.cw; height: 24
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    text: root.locale.dayName((root.firstDay + index) % 7, Locale.NarrowFormat).toUpperCase()
                    color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold
                }
            }
            Repeater {
                model: root.cells
                delegate: Item {
                    id: cell
                    required property var modelData
                    readonly property bool isToday: modelData.y === root.today.getFullYear() && modelData.m === root.today.getMonth() && modelData.d === root.today.getDate()
                    width: grid.cw; height: 36
                    Rectangle {
                        anchors.centerIn: parent
                        width: 32; height: 32; radius: 16
                        visible: cell.isToday
                        color: Theme.fill
                    }
                    // Pasar el mouse por un día lo marca con un círculo suave (mismo tamaño que "hoy").
                    Rectangle {
                        anchors.centerIn: parent
                        width: 32; height: 32; radius: 16
                        color: Theme.hover
                        opacity: dayHover.hovered && !cell.isToday ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                    HoverHandler { id: dayHover }
                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.d
                        color: cell.isToday ? Theme.onAccent : cell.modelData.inMonth ? Theme.textPrimary : Theme.textSecondary
                        opacity: cell.modelData.inMonth || cell.isToday ? 1 : 0.5
                        font.family: Theme.font; font.pixelSize: 13
                        font.weight: cell.isToday ? Font.DemiBold : Font.Normal
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }

        // Volver al mes actual (solo si se navegó a otro).
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property bool away: root.year !== root.today.getFullYear() || root.month !== root.today.getMonth()
            opacity: away ? 1 : 0
            text: I18n.tr("Hoy")
            color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: 13; font.underline: hm.containsMouse
            MouseArea { id: hm; anchors.fill: parent; anchors.margins: -6; enabled: parent.away; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.reset() }
        }
    }

    // Rueda o deslizar con dos dedos sobre el calendario: mes anterior/siguiente (una muesca = un mes).
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        property real acc: 0
        onWheel: w => {
            acc += w.angleDelta.y
            if (Math.abs(acc) < 120) return
            root.shift(acc > 0 ? -1 : 1); acc = 0
        }
    }
}
