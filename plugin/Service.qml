import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons as Commons
Item {
 id: root
 property var shell: null
 property var manifest: null
 property string selected: ""
 property double lastChange: 0
 property double releasedAt: 0
 property int anchorX: 0
 property int anchorY: 0
 property string monitorName: ""
 property string payload: ""
 readonly property string settingsPath: (Quickshell.env("XDG_CONFIG_HOME")
     || Quickshell.env("HOME") + "/.config") + "/Omachat/omachat.conf"
 readonly property string appearanceSettings:
     (settingsFile.text().match(/^\[General\][^\S\r\n]*\r?\n([^\[]*)/m) || [])[1] || ""

 OmachatPalette {
    id: colors
    codex: !/^selectionProvider=Antigravity\s*$/m.test(root.appearanceSettings)
    darkMode: /^darkMode=true\s*$/m.test(root.appearanceSettings)
 }
 Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

 FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
 }

 component SelectionAction: Button {
    id: action
    property bool primary: false
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    implicitHeight: 34
    padding: 5
    leftPadding: 10
    rightPadding: 10
    hoverEnabled: true
    font.pixelSize: 12
    font.weight: Font.DemiBold
    contentItem: Text {
        text: action.text
        textFormat: Text.PlainText
        color: action.primary ? colors.onAccent : colors.accent
        font: action.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: 9
        color: action.primary
            ? (action.hovered ? Qt.darker(colors.accent, 1.08) : colors.accent)
            : (action.hovered ? colors.pressed : colors.tint)
    }
 }
 property var config: {
  var cfg = shell && shell.shellConfig ? shell.shellConfig : null
  var layout = cfg && cfg.bar ? cfg.bar.layout : shell && shell.barConfig ? shell.barConfig.layout : null
  if (layout) for (var k in layout) for (var e of layout[k]) if(e.id === "local.omachat") return e
  return ({})
 }
 FileView {id: engine; path: Qt.resolvedUrl("engine.lua").toString().replace("file://", ""); onLoaded: install.restart()}
 Timer {id: install; interval: 500; onTriggered: {if(!inject.running) {inject.command=["hyprctl","eval", "local function installEngine()\n" + engine.text() + "\nend\ninstallEngine()"];inject.running=true}}}
 Process {id: inject}
 Process {id: watch; running: true; command: ["wl-paste","--primary","--watch","sh","-c","printf 'changed\\n'"]; stdout: SplitParser {onRead: data => {root.lastChange=Date.now()}}}
 Process {
  id: capture
  command: ["python3", Qt.resolvedUrl("selection.py").toString().replace("file://", "")]
  stdout: StdioCollector {onStreamFinished: {try {var data=JSON.parse(text); if(data.text && Date.now()-root.releasedAt<1200){root.selected=data.text;popup.visible=true;hide.restart()}}catch(e){}}}
 }
 Process {id: launch; command: ["omachat","open","--request-stdin"]; stdinEnabled: true; onStarted: {write(root.payload+"\n");stdinEnabled=false}}
 function openChat(explain, newChat) {root.payload=JSON.stringify({text: root.selected,explain:explain,newChat:!!newChat});popup.visible=false;launch.stdinEnabled=true;launch.running=true}
 Timer {id: hide; interval: 6000; onTriggered: popup.visible=false}
 Timer {id: settle; interval: 110; onTriggered: {if(!capture.running)capture.running=true}}
 Connections {
  target: Hyprland
  function onRawEvent(event) {
   if(event.name === "configreloaded") {install.restart();popup.visible=false;return}
   if(event.name !== "custom")return
   var p=String(event.data).split("|");if(p[0]!=="omachat")return
   if(p[1]==="key"||p[1]==="scroll") {popup.visible=false;return}
   if(p[1]!=="release"||root.config.paused)return
   var klass=decodeURIComponent(p[11]||"");
   if(klass==="omachat"||klass.indexOf("layer:")===0)return
   var excluded=String(root.config.excludedApps||"").split(",").map(s=>s.trim());if(excluded.indexOf(klass)>=0)return
   if(/terminal|alacritty|kitty|foot|ghostty|wezterm|konsole/i.test(klass)&&!(Number(p[4])&1))return
   if(Date.now()-root.lastChange>700)return
   root.releasedAt=Date.now();root.monitorName=decodeURIComponent(p[5]);root.anchorX=Number(p[2])-Number(p[6]);root.anchorY=Number(p[3])-Number(p[7]);settle.restart()
  }
 }
 PanelWindow {
    id: popup
    visible: false
    color: "transparent"
    implicitWidth: Math.min((screen ? screen.width : 1920) - 12, actions.implicitWidth + 12)
    implicitHeight: actions.implicitHeight + 12
    screen: Quickshell.screens.find(s => s.name === root.monitorName) || Quickshell.screens[0]
    WlrLayershell.namespace: "omachat-actions"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true }
    margins {
        left: Math.max(6, Math.min(root.anchorX - popup.implicitWidth / 2,
                  (popup.screen ? popup.screen.width : 1920) - popup.implicitWidth - 6))
        top: Math.max(6, root.anchorY - popup.implicitHeight - 10)
    }

    Rectangle {
        anchors.fill: parent
        color: colors.surface
        border.color: colors.line
        radius: 14

        RowLayout {
            id: actions
            anchors.fill: parent
            anchors.margins: 6
            spacing: 5
            layoutDirection: Commons.I18n.rightToLeft ? Qt.RightToLeft : Qt.LeftToRight
            SelectionAction {
                text: strings.t("selection.explain")
                primary: true
                onClicked: root.openChat(true)
            }
            SelectionAction {
                text: strings.t("selection.chat")
                onClicked: root.openChat(false)
            }
            SelectionAction {
                text: strings.t("selection.newChat")
                onClicked: root.openChat(true, true)
            }
        }
    }
 }
}
