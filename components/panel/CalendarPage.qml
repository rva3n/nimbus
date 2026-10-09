import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"
import ".."

// Страница «Календарь» — наполняется в волне 2.
ColumnLayout {
    id: page
    property var win: null
    Layout.fillWidth: true
    spacing: Theme.dp(10)
    visible: win !== null && win.mode === "panel" && win.page === "calendar"
}
