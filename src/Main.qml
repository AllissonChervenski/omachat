import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

ApplicationWindow {
    id: win
    width: Math.min(settings.windowWidth, Screen.width - 48)
    height: Math.min(settings.windowHeight, Screen.height - 80)
    minimumWidth: 280
    minimumHeight: 420
    visible: true
    title: "Omachat"
    color: canvas
    font.pixelSize: 13

    readonly property bool codex: backend.provider === "Codex"
    readonly property bool compact: width < 470
    readonly property bool darkMode: settings.darkMode
    readonly property alias accent: colors.accent
    readonly property alias onAccent: colors.onAccent
    readonly property alias ink: colors.ink
    readonly property alias muted: colors.muted
    readonly property alias canvas: colors.canvas
    readonly property alias tint: colors.tint
    readonly property alias line: colors.line
    readonly property alias surface: colors.surface
    readonly property alias pressed: colors.pressed
    readonly property alias errorInk: colors.errorInk
    readonly property int gutter: compact ? 10 : 16

    palette.window: canvas
    palette.windowText: ink
    palette.base: surface
    palette.text: ink
    palette.button: surface
    palette.buttonText: ink
    palette.highlight: accent
    palette.highlightedText: onAccent
    palette.placeholderText: muted
    palette.light: tint
    palette.midlight: pressed
    palette.mid: line
    palette.dark: line
    palette.shadow: "#0f1017"
    palette.toolTipBase: surface
    palette.toolTipText: ink

    OmachatPalette {
        id: colors
        codex: win.codex
        darkMode: win.darkMode
    }

    Component.onCompleted: syncSelectionProvider()
    onCodexChanged: Qt.callLater(syncSelectionProvider)
    function syncSelectionProvider() {
        settings.setValue("selectionProvider", backend.provider)
        settings.sync()
    }

    Settings {
        id: settings
        property int windowWidth: 540
        property int windowHeight: 780
        property bool darkMode: false
    }
    onClosing: {
        settings.windowWidth = width
        settings.windowHeight = height
    }

    function sendMessage() {
        if (!backend.busy && input.text.trim()) {
            backend.send(input.text)
            input.clear()
        }
    }

    function modelName(slug) {
        if (slug === "gpt-6-luna")
            return "GPT-6 Luna"
        if (slug === "gemini-4-hydrogen-medium")
            return "Gemini 4 Hydrogen · Medium"
        return slug
    }

    Shortcut { sequence: "Ctrl+N"; onActivated: backend.newChat() }
    Shortcut { sequence: "Ctrl+Return"; onActivated: win.sendMessage() }
    Shortcut { sequence: "Escape"; onActivated: win.hide() }

    component ActionButton: Button {
        id: action
        property bool primary: false
        implicitHeight: 32
        leftPadding: 9
        rightPadding: 9
        font.pixelSize: 12
        contentItem: Text {
            text: action.text
            font: action.font
            color: action.primary && action.enabled ? win.onAccent : win.accent
            opacity: action.enabled ? 1 : 0.55
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }
        background: Rectangle {
            radius: 9
            color: action.primary && action.enabled ? win.accent
                  : action.hovered || action.primary ? win.tint : "transparent"
            border.width: action.visualFocus ? 2 : 0
            border.color: win.accent
        }
    }

    component Picker: ComboBox {
        id: picker
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        implicitHeight: 34
        leftPadding: 9
        rightPadding: 24
        font.pixelSize: 12
        contentItem: Text {
            text: picker.displayText
            font: picker.font
            color: win.ink
            opacity: picker.enabled ? 1 : 0.6
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }
        indicator: Text {
            text: "▾"
            color: win.accent
            anchors.right: parent.right
            anchors.rightMargin: 9
            anchors.verticalCenter: parent.verticalCenter
        }
        background: Rectangle {
            color: picker.hovered ? win.tint : win.surface
            radius: 9
            border.color: picker.visualFocus ? win.accent : win.line
        }
        delegate: ItemDelegate {
            required property string modelData
            required property int index
            width: picker.popup.width
            highlighted: picker.highlightedIndex === index
            contentItem: Text {
                text: modelData
                font: picker.font
                color: win.ink
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
            background: Rectangle { color: parent.highlighted ? win.tint : win.surface }
        }
        popup: Popup {
            y: picker.height + 4
            width: picker.width
            padding: 4
            implicitHeight: Math.min(255, list.contentHeight + 8)
            contentItem: ListView {
                id: list
                clip: true
                model: picker.popup.visible ? picker.delegateModel : null
                currentIndex: picker.highlightedIndex
                ScrollBar.vertical: ScrollBar {}
            }
            background: Rectangle { radius: 10; color: win.surface; border.color: win.line }
        }
        ToolTip.visible: hovered && contentItem.truncated && !popup.visible
        ToolTip.delay: 450
        ToolTip.text: displayText
    }

    header: Rectangle {
        implicitHeight: 52
        color: win.surface
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: win.line }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: win.gutter
            anchors.rightMargin: win.gutter
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                spacing: 7
                DragHandler { onActiveChanged: if (active) win.startSystemMove() }
                Rectangle {
                    implicitWidth: 27
                    implicitHeight: 27
                    radius: 9
                    color: win.tint
                    Text { anchors.centerIn: parent; text: "✦"; color: win.accent; font.pixelSize: 15 }
                }
                Label {
                    Layout.fillWidth: true
                    text: "Omachat"
                    color: win.ink
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }

            ActionButton { text: qsTr("History"); onClicked: history.open() }
            ActionButton {
                text: win.compact ? "+" : qsTr("New chat")
                Accessible.name: qsTr("New chat")
                enabled: !backend.busy
                onClicked: backend.newChat()
                ToolTip.visible: hovered && win.compact
                ToolTip.text: qsTr("New chat")
            }
            ActionButton {
                id: settingsButton
                text: "⋯"
                Accessible.name: qsTr("Settings")
                onClicked: menu.open()
                Menu {
                    id: menu
                    popupType: Popup.Item
                    x: settingsButton.width - width
                    y: settingsButton.height + 4
                    width: Math.min(240, win.width - 2 * win.gutter)
                    padding: 5
                    palette: win.palette
                    background: Rectangle {
                        radius: 10
                        color: win.surface
                        border.color: win.line
                    }
                    MenuItem {
                        text: qsTr("Night mode")
                        checkable: true
                        checked: settings.darkMode
                        onTriggered: {
                            settings.darkMode = checked
                            settings.setValue("darkMode", checked)
                            settings.sync()
                        }
                    }
                    MenuSeparator {}
                    MenuItem { text: qsTr("Sign in with provider"); onTriggered: backend.login() }
                    MenuItem { text: qsTr("Open history folder"); onTriggered: backend.openData() }
                    MenuItem { text: qsTr("Refresh models"); onTriggered: backend.refreshModels() }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: win.gutter
        spacing: 9
        LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true

        GridLayout {
            Layout.fillWidth: true
            columns: win.compact ? 2 : 3
            columnSpacing: 7
            rowSpacing: 6

            Picker {
                Layout.row: 0
                Layout.column: 0
                Layout.columnSpan: win.compact && !win.codex ? 2 : 1
                Layout.preferredWidth: 108
                Accessible.name: qsTr("Provider")
                enabled: !backend.busy
                model: ["Codex", "Antigravity"]
                currentIndex: win.codex ? 0 : 1
                onActivated: backend.provider = currentText
            }
            Picker {
                id: modelPicker
                readonly property var slugs: backend.models.indexOf(backend.model) < 0
                    ? [backend.model].concat(backend.models) : backend.models
                Layout.row: win.compact ? 1 : 0
                Layout.column: win.compact ? 0 : 1
                Layout.columnSpan: win.compact ? 2 : 1
                Layout.preferredWidth: 240
                Accessible.name: qsTr("Model")
                enabled: !backend.busy
                model: slugs.map(win.modelName).concat([qsTr("Custom model…")])
                currentIndex: slugs.indexOf(backend.model)
                onActivated: function(index) {
                    if (index < slugs.length) {
                        backend.model = slugs[index]
                    } else {
                        currentIndex = Qt.binding(function() { return slugs.indexOf(backend.model) })
                        customModel.open()
                    }
                }
            }
            Picker {
                id: effortPicker
                Layout.row: 0
                Layout.column: win.compact ? 1 : 2
                Layout.preferredWidth: 120
                visible: win.codex
                enabled: !backend.busy && backend.efforts.length > 0
                Accessible.name: qsTr("Reasoning effort")
                model: [qsTr("Default effort")].concat(backend.efforts)
                currentIndex: backend.effort ? backend.efforts.indexOf(backend.effort) + 1 : 0
                onActivated: function(index) {
                    backend.effort = index ? backend.efforts[index - 1] : ""
                }
                ToolTip.visible: hovered && !popup.visible
                ToolTip.text: qsTr("Reasoning effort")
            }
        }

        Frame {
            Layout.fillWidth: true
            visible: backend.selection.length > 0
            padding: 9
            background: Rectangle { color: win.tint; radius: 12 }
            contentItem: ColumnLayout {
                spacing: 4
                Label {
                    text: qsTr("Selected text")
                    color: win.accent
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
                ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(win.compact ? 70 : 98, selected.implicitHeight)
                    contentWidth: availableWidth
                    clip: true
                    TextArea {
                        id: selected
                        text: backend.selection
                        readOnly: true
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.PlainText
                        selectByMouse: true
                        padding: 0
                        background: null
                    }
                }
            }
        }

        ListView {
            id: chat
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 45
            clip: true
            spacing: 8
            model: backend.messages
            onCountChanged: Qt.callLater(positionViewAtEnd)
            ScrollBar.vertical: ScrollBar {}

            Label {
                visible: chat.count === 0
                width: Math.min(parent.width, 330)
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: win.muted
                text: backend.selection ? qsTr("Ask about the selected text.") : qsTr("Ask a question or select text to start.")
            }

            delegate: Frame {
                required property var modelData
                width: chat.width - 6
                padding: 9
                background: Rectangle {
                    color: modelData.role === "user" ? win.tint : win.surface
                    radius: 12
                    border.color: win.line
                }
                contentItem: ColumnLayout {
                    spacing: 3
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.fillWidth: true
                            text: modelData.role === "user" ? qsTr("You") : qsTr("Assistant")
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: win.accent
                        }
                        ActionButton { text: qsTr("Copy"); onClicked: backend.copy(modelData.content) }
                    }
                    TextArea {
                        Layout.fillWidth: true
                        text: modelData.content
                        readOnly: true
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.PlainText
                        selectByMouse: true
                        padding: 0
                        background: null
                    }
                }
            }
        }

        RowLayout {
            visible: backend.busy
            BusyIndicator { running: backend.busy; Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
            Label {
                text: qsTr("Waiting for the answer…")
                color: win.muted
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            ActionButton { text: qsTr("Stop"); onClicked: backend.cancel() }
        }

        ScrollView {
            visible: backend.error.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(60, errorLabel.implicitHeight)
            contentWidth: availableWidth
            clip: true
            TextArea {
                id: errorLabel
                text: backend.error
                padding: 0
                color: win.errorInk
                readOnly: true
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.PlainText
                background: null
            }
        }

        Frame {
            Layout.fillWidth: true
            padding: 7
            background: Rectangle { color: win.surface; radius: 13; border.color: win.line }
            contentItem: ColumnLayout {
                spacing: 3
                ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: win.compact ? 50 : 66
                    contentWidth: availableWidth
                    clip: true
                    TextArea {
                        id: input
                        placeholderText: qsTr("Ask a question…")
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        padding: 5
                        background: null
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: "Ctrl+Enter"
                        color: win.muted
                        font.pixelSize: 11
                        Layout.leftMargin: 5
                        Layout.fillWidth: true
                    }
                    ActionButton {
                        text: qsTr("Send")
                        primary: true
                        enabled: !backend.busy && input.text.trim().length > 0
                        onClicked: win.sendMessage()
                    }
                    ActionButton {
                        text: "◢"
                        Accessible.name: qsTr("Resize window")
                        onPressed: win.startSystemResize(Qt.RightEdge | Qt.BottomEdge)
                    }
                }
            }
        }
    }

    Drawer {
        id: history
        width: Math.min(win.width * 0.92, 420)
        height: win.height
        padding: 12
        background: Rectangle { color: win.surface; radius: 12; border.color: win.line }
        contentItem: ColumnLayout {
            Label {
                text: qsTr("Conversations on this computer")
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: backend.conversations
                delegate: RowLayout {
                    required property var modelData
                    width: ListView.view.width
                    ActionButton {
                        text: modelData.title || qsTr("New chat")
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        enabled: !backend.busy
                        onClicked: { backend.load(modelData.id); history.close() }
                    }
                    ActionButton {
                        text: "×"
                        Accessible.name: qsTr("Delete conversation")
                        enabled: !backend.busy
                        onClicked: { confirmDelete.chatId = modelData.id; confirmDelete.open() }
                    }
                }
            }
        }
    }

    Dialog {
        id: confirmDelete
        property string chatId
        anchors.centerIn: parent
        width: Math.min(330, win.width - 24)
        modal: true
        title: qsTr("Delete this conversation?")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: backend.remove(chatId)
    }

    Dialog {
        id: customModel
        anchors.centerIn: parent
        width: Math.min(360, win.width - 24)
        modal: true
        title: qsTr("Custom model")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onOpened: {
            modelId.text = backend.model
            modelId.selectAll()
            modelId.forceActiveFocus()
        }
        onAccepted: backend.model = modelId.text
        TextField {
            id: modelId
            width: parent.width
            placeholderText: qsTr("Model identifier")
            onAccepted: customModel.accept()
        }
    }
}
