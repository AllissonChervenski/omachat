import QtQuick

QtObject {
    property bool codex: true
    property bool darkMode: false

    readonly property color accent: codex
        ? (darkMode ? "#64e3ad" : "#087761")
        : (darkMode ? "#91baff" : "#245cbd")
    readonly property color onAccent: darkMode ? "#21222c" : "#ffffff"
    readonly property color ink: darkMode ? "#f8f8f2" : "#182623"
    readonly property color muted: darkMode ? "#bcc0d7" : "#52655f"
    readonly property color canvas: darkMode ? "#282a36" : (codex ? "#f5f9f7" : "#f5f8fd")
    readonly property color tint: codex
        ? (darkMode ? "#31443f" : "#e4f3ed")
        : (darkMode ? "#333f59" : "#e7efff")
    readonly property color line: darkMode ? "#53576e" : (codex ? "#d6e4de" : "#d8e3f4")
    readonly property color surface: darkMode ? "#21222c" : "#ffffff"
    readonly property color pressed: darkMode ? "#44475a" : Qt.darker(tint, 1.07)
    readonly property color errorInk: darkMode ? "#ff9191" : "#a22630"
}
