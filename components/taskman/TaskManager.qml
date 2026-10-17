import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Диспетчер задач в стиле Windows 11 Task Manager (адаптация Material 3 Expressive):
// Верхняя панель навигации с 3 представлениями («Процессы» со счётчиком,
// «Производительность» с мини-сводкой ЦП/ОЗУ, «Система и Службы»),
// живыми пилюлями телеметрии (ЦП, ОЗУ, ГП, Сеть) и кнопкой закрытия.
FocusScope {
    id: tm

    property var shell: null
    property int initialTab: 0
    property int tab: 0

    // при открытии — на вкладку, запрошенную извне (IPC/кейбинд)
    onVisibleChanged: if (visible) {
        tm.forceActiveFocus();
        tab = initialTab;
        if (tm.shell)
            tm.shell.taskmanTab = tab;
        tm.syncPollers();
    } else {
        tm.syncPollers();
    }

    onInitialTabChanged: {
        if (tm.visible)
            tm.tab = tm.initialTab;
    }
    onTabChanged: tm.syncPollers()

    function syncPollers() {
        ProcList.active = tm.visible;
        SysStats.taskmanActive = tm.visible;
    }

    function selectTab(idx) {
        tm.tab = idx;
        if (tm.shell)
            tm.shell.taskmanTab = idx;
    }

    function openPerfResource(resKey) {
        monitorTab.selectedResource = resKey;
        tm.selectTab(1);
    }

    function fmtGbShort(bytes) {
        if (!isFinite(bytes) || bytes <= 0)
            return "0.0";
        return (bytes / 1073741824).toFixed(1);
    }

    function fmtRateCompact(b) {
        if (!isFinite(b) || b <= 0)
            return "0К";
        if (b >= 1048576)
            return (b / 1048576).toFixed(1) + "М";
        if (b >= 1024)
            return Math.round(b / 1024) + "К";
        return Math.round(b) + "Б";
    }

    Component.onCompleted: tm.syncPollers()

    Layout.fillWidth: true
    focus: visible
    implicitWidth: contentLayout.implicitWidth
    implicitHeight: contentLayout.implicitHeight

    ColumnLayout {
        id: contentLayout

        anchors.fill: parent
        spacing: Theme.dp(10)

        // ── Верхняя панель (Windows 11 Task Manager Header + Nav) ──────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.dp(48)
            radius: Theme.rad(16)
            color: Theme.mLow
            border.width: 1
            border.color: Theme.alpha(Theme.outline, 0.16)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.dp(10)
                anchors.rightMargin: Theme.dp(8)
                spacing: Theme.dp(6)

                // Значок и заголовок окна
                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Theme.dp(8)

                    Rectangle {
                        implicitWidth: Theme.dp(30)
                        implicitHeight: Theme.dp(30)
                        radius: Theme.rad(9)
                        color: Theme.primaryContainer

                        Icon {
                            anchors.centerIn: parent
                            name: "browse_activity"
                            size: Theme.dp(18)
                            color: Theme.fgPrimaryContainer
                        }
                    }

                    LText {
                        role: "titleSmall"
                        weight: 620
                        text: "Диспетчер задач"
                        color: Theme.text
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: Theme.dp(2)
                    Layout.rightMargin: Theme.dp(2)
                    width: 1
                    height: Theme.dp(22)
                    color: Theme.divider
                }

                // ── 3 вкладки навигации ────────────────────────────────
                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Theme.dp(5)

                    // 0: Процессы (icon: "apps", badge ProcList.totalCount)
                    Rectangle {
                        readonly property bool active: tm.tab === 0
                        implicitHeight: Theme.dp(34)
                        implicitWidth: nav0Row.implicitWidth + Theme.dp(20)
                        radius: active ? Theme.rad(10) : Theme.rad(17)
                        color: active ? Theme.secondaryContainer : "transparent"

                        Behavior on color { ColorAnimation { duration: Theme.durFastEffects } }
                        Behavior on radius { NumberAnimation { duration: Theme.durFastSpatial } }

                        StateLayer {
                            radius: parent.radius
                            tint: parent.active ? Theme.fgSecondaryContainer : Theme.text
                            onClicked: tm.selectTab(0)
                        }

                        RowLayout {
                            id: nav0Row
                            anchors.centerIn: parent
                            spacing: Theme.dp(6)

                            Icon {
                                name: "apps"
                                size: Theme.dp(17)
                                fill: tm.tab === 0 ? 1 : 0
                                color: tm.tab === 0 ? Theme.primary : Theme.subtext
                            }

                            LText {
                                role: "labelLarge"
                                text: "Процессы"
                                color: tm.tab === 0 ? Theme.fgSecondaryContainer : Theme.text
                            }

                            Badge {
                                visible: ProcList.totalCount > 0
                                count: ProcList.totalCount
                                max: 999
                                tone: tm.tab === 0 ? "accent" : "neutral"
                            }
                        }

                        Rectangle {
                            visible: tm.tab === 0
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Theme.dp(18)
                            height: Theme.dp(2)
                            radius: 1
                            color: Theme.primary
                        }
                    }

                    // 1: Производительность (icon: "monitoring", mini-summary)
                    Rectangle {
                        readonly property bool active: tm.tab === 1
                        implicitHeight: Theme.dp(34)
                        implicitWidth: nav1Row.implicitWidth + Theme.dp(20)
                        radius: active ? Theme.rad(10) : Theme.rad(17)
                        color: active ? Theme.secondaryContainer : "transparent"

                        Behavior on color { ColorAnimation { duration: Theme.durFastEffects } }
                        Behavior on radius { NumberAnimation { duration: Theme.durFastSpatial } }

                        StateLayer {
                            radius: parent.radius
                            tint: parent.active ? Theme.fgSecondaryContainer : Theme.text
                            onClicked: tm.selectTab(1)
                        }

                        RowLayout {
                            id: nav1Row
                            anchors.centerIn: parent
                            spacing: Theme.dp(6)

                            Icon {
                                name: "monitoring"
                                size: Theme.dp(17)
                                fill: tm.tab === 1 ? 1 : 0
                                color: tm.tab === 1 ? Theme.primary : Theme.subtext
                            }

                            LText {
                                role: "labelLarge"
                                text: "Производительность"
                                color: tm.tab === 1 ? Theme.fgSecondaryContainer : Theme.text
                            }

                            Rectangle {
                                implicitHeight: Theme.dp(18)
                                implicitWidth: miniPerfTxt.implicitWidth + Theme.dp(10)
                                radius: Theme.dp(9)
                                color: tm.tab === 1 ? Theme.alpha(Theme.primary, 0.2) : Theme.bgTrack

                                LText {
                                    id: miniPerfTxt
                                    anchors.centerIn: parent
                                    role: "labelSmall"
                                    tabular: true
                                    color: tm.tab === 1 ? Theme.primary : Theme.subtext
                                    text: SysStats.cpuPercent + "% · " + Math.round(SysStats.memPct * 100) + "%"
                                }
                            }
                        }

                        Rectangle {
                            visible: tm.tab === 1
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Theme.dp(18)
                            height: Theme.dp(2)
                            radius: 1
                            color: Theme.primary
                        }
                    }

                    // 2: Система и Службы (icon: "terminal")
                    Rectangle {
                        readonly property bool active: tm.tab === 2
                        implicitHeight: Theme.dp(34)
                        implicitWidth: nav2Row.implicitWidth + Theme.dp(20)
                        radius: active ? Theme.rad(10) : Theme.rad(17)
                        color: active ? Theme.secondaryContainer : "transparent"

                        Behavior on color { ColorAnimation { duration: Theme.durFastEffects } }
                        Behavior on radius { NumberAnimation { duration: Theme.durFastSpatial } }

                        StateLayer {
                            radius: parent.radius
                            tint: parent.active ? Theme.fgSecondaryContainer : Theme.text
                            onClicked: tm.selectTab(2)
                        }

                        RowLayout {
                            id: nav2Row
                            anchors.centerIn: parent
                            spacing: Theme.dp(6)

                            Icon {
                                name: "terminal"
                                size: Theme.dp(17)
                                fill: tm.tab === 2 ? 1 : 0
                                color: tm.tab === 2 ? Theme.primary : Theme.subtext
                            }

                            LText {
                                role: "labelLarge"
                                text: "Система и Службы"
                                color: tm.tab === 2 ? Theme.fgSecondaryContainer : Theme.text
                            }
                        }

                        Rectangle {
                            visible: tm.tab === 2
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Theme.dp(18)
                            height: Theme.dp(2)
                            radius: 1
                            color: Theme.primary
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // ── Живые пилюли сводки в шапке ────────────────────────
                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Theme.dp(5)

                    // ЦП: XX%
                    Rectangle {
                        implicitHeight: Theme.dp(26)
                        implicitWidth: cpuPillRow.implicitWidth + Theme.dp(12)
                        radius: Theme.dp(8)
                        color: SysStats.cpuPercent > 80
                            ? Theme.alpha(Theme.errorContainer, 0.55)
                            : (SysStats.cpuPercent > 50 ? Theme.alpha(Theme.warning, 0.2) : Theme.mHigh)

                        StateLayer {
                            radius: parent.radius
                            tint: Theme.text
                            onClicked: tm.openPerfResource("cpu")
                        }

                        RowLayout {
                            id: cpuPillRow
                            anchors.centerIn: parent
                            spacing: Theme.dp(4)

                            LText {
                                role: "labelSmall"
                                color: Theme.subtext
                                text: "ЦП:"
                            }
                            LText {
                                role: "labelSmall"
                                tabular: true
                                weight: 650
                                color: SysStats.cpuPercent > 80 ? Theme.error
                                     : (SysStats.cpuPercent > 50 ? Theme.warning : Theme.text)
                                text: SysStats.cpuPercent + "%"
                            }
                        }
                    }

                    // ОЗУ: X.X / Y.Y ГБ
                    Rectangle {
                        implicitHeight: Theme.dp(26)
                        implicitWidth: memPillRow.implicitWidth + Theme.dp(12)
                        radius: Theme.dp(8)
                        color: SysStats.memPct > 0.88
                            ? Theme.alpha(Theme.errorContainer, 0.55)
                            : Theme.mHigh

                        StateLayer {
                            radius: parent.radius
                            tint: Theme.text
                            onClicked: tm.openPerfResource("memory")
                        }

                        RowLayout {
                            id: memPillRow
                            anchors.centerIn: parent
                            spacing: Theme.dp(4)

                            LText {
                                role: "labelSmall"
                                color: Theme.subtext
                                text: "ОЗУ:"
                            }
                            LText {
                                role: "labelSmall"
                                tabular: true
                                weight: 650
                                color: SysStats.memPct > 0.88 ? Theme.error : Theme.text
                                text: tm.fmtGbShort(SysStats.memUsed) + " / " + tm.fmtGbShort(SysStats.memTotal) + " ГБ"
                            }
                        }
                    }

                    // ГП: XX%
                    Rectangle {
                        visible: SysStats.gpuAvailable
                        implicitHeight: Theme.dp(26)
                        implicitWidth: gpuPillRow.implicitWidth + Theme.dp(12)
                        radius: Theme.dp(8)
                        color: Theme.mHigh

                        StateLayer {
                            radius: parent.radius
                            tint: Theme.text
                            onClicked: tm.openPerfResource("gpu")
                        }

                        RowLayout {
                            id: gpuPillRow
                            anchors.centerIn: parent
                            spacing: Theme.dp(4)

                            LText {
                                role: "labelSmall"
                                color: Theme.subtext
                                text: "ГП:"
                            }
                            LText {
                                role: "labelSmall"
                                tabular: true
                                weight: 650
                                color: Theme.text
                                text: SysStats.gpuUsage + "%"
                            }
                        }
                    }

                    // Сеть: ↓X ↑Y
                    Rectangle {
                        implicitHeight: Theme.dp(26)
                        implicitWidth: netPillRow.implicitWidth + Theme.dp(12)
                        radius: Theme.dp(8)
                        color: Theme.mHigh

                        StateLayer {
                            radius: parent.radius
                            tint: Theme.text
                            onClicked: tm.openPerfResource("network")
                        }

                        RowLayout {
                            id: netPillRow
                            anchors.centerIn: parent
                            spacing: Theme.dp(4)

                            LText {
                                role: "labelSmall"
                                color: Theme.subtext
                                text: "Сеть:"
                            }
                            LText {
                                role: "labelSmall"
                                tabular: true
                                weight: 650
                                color: Theme.text
                                text: "↓" + tm.fmtRateCompact(SysStats.netRx) + " ↑" + tm.fmtRateCompact(SysStats.netTx)
                            }
                        }
                    }
                }

                IconButton {
                    Layout.alignment: Qt.AlignVCenter
                    size: "s"
                    variant: "tonal"
                    icon: "close"
                    tooltip: "Закрыть (Esc)"
                    onClicked: if (tm.shell) tm.shell.closeOverlays()
                }
            }
        }

        // ── Содержимое вкладок ────────────────────────────────────────
        ProcessesTab {
            id: processesTab
            visible: tm.tab === 0
            shell: tm.shell
        }

        MonitorTab {
            id: monitorTab
            visible: tm.tab === 1
            shell: tm.shell
        }

        AboutTab {
            id: aboutTab
            visible: tm.tab === 2
            shell: tm.shell
        }
    }

    // Горячие клавиши: ESC закрывает диспетчер, Alt+1..3 переключают вкладки
    Keys.onPressed: (event) => {
        if (event.modifiers & Qt.AltModifier) {
            if (event.key === Qt.Key_1) { tm.selectTab(0); event.accepted = true; return; }
            if (event.key === Qt.Key_2) { tm.selectTab(1); event.accepted = true; return; }
            if (event.key === Qt.Key_3) { tm.selectTab(2); event.accepted = true; return; }
        }
    }

    Keys.onEscapePressed: (event) => {
        if (tm.shell) tm.shell.closeOverlays();
        event.accepted = true;
    }
}
