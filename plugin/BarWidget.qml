import QtQuick
import Quickshell
import Quickshell.Io
Item {
 property var shell: null
 property var manifest: null
 implicitWidth: 30; implicitHeight: 30
 Text {anchors.centerIn: parent; text: "✦"; color: "#FFD60A"; font.pixelSize: 20; textFormat: Text.PlainText}
 MouseArea {anchors.fill: parent; onClicked: launch.running=true}
 Process {id: launch; command: ["omachat", "open", "--selection"]}
}
