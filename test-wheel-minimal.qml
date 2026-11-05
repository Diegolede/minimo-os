// Test mínimo para verificar si onWheel funciona en Quickshell 0.3.2
// Ejecutar con: quickshell -c test-wheel-minimal.qml
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    PanelWindow {
        id: testWin
        anchors { top: true; left: true; right: true }
        height: 100
        color: "red"
        
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "test-wheel"
        
        MouseArea {
            id: testArea
            anchors.fill: parent
            hoverEnabled: true
            
            onWheel: wheel => {
                console.log("[TEST] onWheel triggered! angleDelta.y:", wheel.angleDelta.y)
                const direction = wheel.angleDelta.y > 0 ? "UP" : "DOWN"
                console.log("[TEST] Direction:", direction)
            }
            
            onEntered: console.log("[TEST] Mouse entered test area")
            onExited: console.log("[TEST] Mouse exited test area")
        }
        
        Text {
            anchors.centerIn: parent
            text: "Hover aquí y usar rueda del mouse\nVer logs en la terminal"
            color: "white"
            font.pixelSize: 16
        }
    }
}
