pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// Вкладка «Система и Службы» диспетчера задач:
// Верхний ряд — карточка-логотип Oberon и neofetch-сводка о системе.
// Нижний ряд — «Топ процессов и Автозапуск Umbriel» (топ процессов по ресурсам +
// службы сессии и команды автозапуска из конфига Umbriel).
ColumnLayout {
    id: root

    property var shell: null

    // ── Константы шелла ────────────────────────────────────────────────
    readonly property string appName: "Oberon"
    readonly property string appVersion: "2.0"
    readonly property string compositorName: "Umbriel"
    readonly property string engineName: "Quickshell"
    readonly property string configPath: "~/oberon"
    readonly property string licenseName: "MIT"

    property var autostartEntries: []
    property var _autostartBuf: []

    // Чтение автозапуска из ~/.config/umbriel/src/general.toml и config.toml
    Process {
        id: autostartProc
        running: true
        command: ["sh", "-c",
            "for f in \"$HOME/.config/umbriel/src/general.toml\" \"$HOME/.config/umbriel/config.toml\"; do " +
            "[ -r \"$f\" ] || continue; " +
            "grep -E 'exec|spawn|autostart' \"$f\" 2>/dev/null | sed 's/^[[:space:]]*//' | head -n 8; " +
            "done"]
        stdout: SplitParser {
            onRead: line => {
                const s = line.trim();
                if (s !== "" && !s.startsWith("#"))
                    root._autostartBuf.push(s);
            }
        }
        onExited: root.autostartEntries = root._autostartBuf
    }

    // Ключевые службы сессии Oberon / Umbriel и проверка их активности в ProcList
    readonly property var sessionServices: {
        const procs = ProcList.items || [];
        const defs = [
            { name: "umbriel", label: "Композитор Umbriel", role: "Wayland WM" },
            { name: "oberonqs", alt: "quickshell", label: "Оболочка Oberon (Quickshell)", role: "UI Shell" },
            { name: "oberonidle", alt: "hypridle", label: "Демон простоя (oberonidle)", role: "Idle / DPMS" },
            { name: "oberonwall", alt: "awww-daemon", label: "Демон обоев (oberonwall)", role: "Wallpaper" },
            { name: "pipewire", label: "Аудиосервер PipeWire", role: "Audio / Video" },
            { name: "NetworkManager", label: "NetworkManager", role: "Сеть" }
        ];
        const out = [];
        for (const d of defs) {
            let foundPid = 0;
            for (let i = 0; i < procs.length; i++) {
                const pn = String(procs[i].name || "").toLowerCase();
                const pa = String(procs[i].args || "").toLowerCase();
                const target1 = d.name.toLowerCase();
                const target2 = d.alt ? d.alt.toLowerCase() : "";
                if (pn.indexOf(target1) !== -1 || pa.indexOf(target1) !== -1
                        || (target2 !== "" && (pn.indexOf(target2) !== -1 || pa.indexOf(target2) !== -1))) {
                    foundPid = procs[i].pid;
                    break;
                }
            }
            out.push({
                label: d.label,
                role: d.role,
                running: foundPid > 0,
                pid: foundPid
            });
        }
        return out;
    }

    // Топ-5 процессов по потреблению ресурсов
    readonly property var topProcs: {
        const list = (ProcList.items || []).slice();
        list.sort((a, b) => (b.cpu * 2 + b.mem) - (a.cpu * 2 + a.mem));
        return list.slice(0, 5);
    }

    // максимальная температура среди датчиков hwmon
    readonly property real maxTempC: {
        let m = SysStats.tempC;
        const list = SysStats.temps || [];
        for (let i = 0; i < list.length; i++)
            if (list[i] && list[i].c > m)
                m = list[i].c;
        return m;
    }

    function fmtGb(bytes) {
        if (bytes === undefined || bytes === null || bytes < 0)
            return "—";
        return (bytes / 1073741824).toFixed(1) + " ГБ";
    }

    function fmtUptime(sec) {
        const d = Math.floor(sec / 86400);
        const h = Math.floor((sec % 86400) / 3600);
        const m = Math.floor((sec % 3600) / 60);
        if (d > 0) return d + " д " + h + " ч";
        return h > 0 ? h + " ч " + m + " мин" : m + " мин";
    }

    function fmtClock() {
        const f = m => m > 0 ? (m / 1000).toFixed(2) : "—";
        if (SysStats.cpuCurMhz <= 0 && SysStats.cpuMaxMhz <= 0)
            return "—";
        return f(SysStats.cpuCurMhz) + "/" + f(SysStats.cpuMaxMhz) + " ГГц";
    }

    function fmtDisk(d) {
        if (!d || !isFinite(d.used) || !isFinite(d.total))
            return "—";
        return (d.used / 1073741824).toFixed(1) + "/" + (d.total / 1073741824).toFixed(1) + " ГБ";
    }

    function orDash(v) { return (v === undefined || v === null || v === "") ? "—" : v }

    Layout.fillWidth: true
    spacing: Theme.dp(12)

    // ── Верхний ряд: карточка-логотип слева + сводка о системе справа ──
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.dp(12)

        // Слева: карточка-логотип, имя и мини-чипы
        Card {
            Layout.preferredWidth: Theme.dp(248)
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            pad: Theme.dp(16)

            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Theme.dp(4)
                implicitWidth: Theme.dp(92)
                implicitHeight: Theme.dp(92)

                MaterialShape {
                    anchors.fill: parent
                    shape: "circle"
                    color: Theme.accentContainer
                }

                Icon {
                    anchors.centerIn: parent
                    name: "cloud"
                    size: Theme.dp(46)
                    color: Theme.fgAccentContainer
                }

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenterOffset: Theme.dp(24)
                    anchors.verticalCenterOffset: -Theme.dp(22)
                    name: "star"
                    size: Theme.dp(16)
                    color: Theme.accent
                }
            }

            LText {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Theme.dp(8)
                role: "headlineSmall"
                color: Theme.text
                text: root.appName
            }

            LText {
                Layout.alignment: Qt.AlignHCenter
                role: "bodySmall"
                color: Theme.subtext
                text: "M3 shell для " + root.compositorName
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Theme.dp(10)
                spacing: Theme.dp(6)

                Chip {
                    size: "sm"
                    kind: "suggestion"
                    interactive: false
                    implicitHeight: Theme.dp(22)
                    horizontalPadding: 8
                    textRole: "labelSmall"
                    backgroundColor: Theme.bgTrack
                    borderWidth: 0
                    customColors: true
                    foregroundColor: Theme.subtext
                    iconColor: Theme.subtext
                    text: root.appVersion
                }
                Chip {
                    size: "sm"
                    kind: "suggestion"
                    interactive: false
                    implicitHeight: Theme.dp(22)
                    horizontalPadding: 8
                    textRole: "labelSmall"
                    backgroundColor: Theme.bgTrack
                    borderWidth: 0
                    customColors: true
                    foregroundColor: Theme.subtext
                    iconColor: Theme.subtext
                    text: root.licenseName
                }
                Chip {
                    size: "sm"
                    kind: "suggestion"
                    interactive: false
                    implicitHeight: Theme.dp(22)
                    horizontalPadding: 8
                    textRole: "labelSmall"
                    backgroundColor: Theme.bgTrack
                    borderWidth: 0
                    customColors: true
                    foregroundColor: Theme.subtext
                    iconColor: Theme.subtext
                    text: root.engineName
                }
            }

            Divider {
                Layout.fillWidth: true
                Layout.topMargin: Theme.dp(10)
                Layout.bottomMargin: Theme.dp(4)
            }

            RowLayout {
                Layout.fillWidth: true
                LText { Layout.fillWidth: true; role: "labelSmall"; color: Theme.subtext; text: "Окна Umbriel" }
                LText { role: "labelMedium"; tabular: true; color: Theme.text; text: String((Umbriel.windows || []).length) }
            }
            RowLayout {
                Layout.fillWidth: true
                LText { Layout.fillWidth: true; role: "labelSmall"; color: Theme.subtext; text: "Процессы / Потоки" }
                LText { role: "labelMedium"; tabular: true; color: Theme.text; text: ProcList.totalCount + " / " + SysStats.cpuThreadsTotal }
            }
        }

        // Справа: Lucid-карточка с двумя колонками инфо-строк
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            title: "Сводка о системе"
            pad: Theme.dp(14)

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.dp(16)

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Theme.dp(1)

                    InfoRow { icon: "info"; label: "ОС"; value: root.orDash(SysStats.distro) }
                    InfoRow { icon: "developer_board"; label: "Ядро"; value: root.orDash(SysStats.kernel) }
                    InfoRow { icon: "monitor"; label: "Платформа"; value: root.orDash(SysStats.host) }
                    InfoRow {
                        icon: "hourglass_top"; label: "Время работы"
                        value: SysStats.uptime > 0 ? root.fmtUptime(SysStats.uptime) : "—"
                    }
                    InfoRow { icon: "memory"; label: "Процессор"; value: root.orDash(SysStats.cpuModel) }
                    InfoRow {
                        icon: "grid_view"; label: "Ядра/потоки"; tabular: true
                        value: SysStats.cores > 0 ? String(SysStats.cores) + " (" + SysStats.cpuVirt + ")" : "—"
                    }
                    InfoRow { icon: "speed"; label: "Частота CPU"; tabular: true; value: root.fmtClock() }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Theme.dp(1)

                    InfoRow { icon: "storage"; label: "Память"; tabular: true; value: root.fmtGb(SysStats.memUsed) + " / " + root.fmtGb(SysStats.memTotal) }
                    InfoRow { icon: "graphic_eq"; label: "Видеокарта"; value: root.orDash(SysStats.gpuModel) }
                    Repeater {
                        model: SysStats.disks
                        delegate: ColumnLayout {
                            id: diskCol
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 0

                            InfoRow {
                                icon: "hard_drive"; label: diskCol.modelData.mount; tabular: true
                                value: root.fmtDisk(diskCol.modelData)
                            }
                        }
                    }
                    InfoRow { icon: "lan"; label: "Сеть"; value: (SysStats.netIface || "—") + (SysStats.netIp ? " · " + SysStats.netIp : "") }
                    InfoRow { icon: "cloud"; label: "Шелл / WM"; value: root.appName + " " + root.appVersion + " · " + root.compositorName }
                    InfoRow { icon: "folder"; label: "Конфиг"; value: root.configPath }
                }
            }
        }
    }

    // ── Нижний ряд: «Топ процессов и Автозапуск Umbriel» ───────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.dp(12)

        // Карточка 1: Топ процессов по ресурсам
        Card {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            title: "Топ процессов по ресурсам"
            pad: Theme.dp(14)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.dp(4)

                Repeater {
                    model: root.topProcs

                    delegate: Rectangle {
                        id: topRow
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: Theme.dp(32)
                        radius: Theme.rad(8)
                        color: Theme.mLow

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.dp(10)
                            anchors.rightMargin: Theme.dp(8)
                            spacing: Theme.dp(8)

                            LText {
                                Layout.fillWidth: true
                                role: "labelLarge"
                                color: Theme.text
                                text: topRow.modelData.name
                                elide: Text.ElideRight
                            }

                            LText {
                                role: "labelSmall"
                                tabular: true
                                color: Theme.subtextDim
                                text: "PID " + topRow.modelData.pid
                            }

                            LText {
                                Layout.preferredWidth: Theme.dp(50)
                                horizontalAlignment: Text.AlignRight
                                role: "labelMedium"
                                tabular: true
                                weight: 650
                                color: topRow.modelData.cpu > 25 ? Theme.warning : Theme.primary
                                text: Number(topRow.modelData.cpu).toFixed(1) + "%"
                            }

                            LText {
                                Layout.preferredWidth: Theme.dp(64)
                                horizontalAlignment: Text.AlignRight
                                role: "labelSmall"
                                tabular: true
                                color: Theme.subtext
                                text: SysStats.formatBytes(topRow.modelData.rss || 0)
                            }

                            IconButton {
                                size: "xs"
                                variant: "standard"
                                icon: "close"
                                tooltip: "Завершить (TERM)"
                                onClicked: ProcList.term(topRow.modelData.pid)
                            }
                        }
                    }
                }
            }
        }

        // Карточка 2: Автозапуск и Службы Umbriel
        Card {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            title: "Топ процессов и Автозапуск Umbriel"
            pad: Theme.dp(14)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.dp(4)

                Repeater {
                    model: root.sessionServices

                    delegate: Rectangle {
                        id: svcRow
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: Theme.dp(28)
                        radius: Theme.rad(8)
                        color: Theme.mLow

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.dp(10)
                            anchors.rightMargin: Theme.dp(10)
                            spacing: Theme.dp(8)

                            Rectangle {
                                width: Theme.dp(7)
                                height: Theme.dp(7)
                                radius: Theme.dp(4)
                                color: svcRow.modelData.running ? Theme.success : Theme.subtextDim
                            }

                            LText {
                                Layout.fillWidth: true
                                role: "bodySmall"
                                color: Theme.text
                                text: svcRow.modelData.label
                                elide: Text.ElideRight
                            }

                            LText {
                                role: "labelSmall"
                                color: Theme.subtextDim
                                text: svcRow.modelData.role
                            }

                            LText {
                                role: "labelSmall"
                                tabular: true
                                weight: 640
                                color: svcRow.modelData.running ? Theme.success : Theme.subtextDim
                                text: svcRow.modelData.running ? ("Активно · " + svcRow.modelData.pid) : "Ожидание"
                            }
                        }
                    }
                }
            }
        }
    }

    // компактная инфо-строка: иконка на bgTrack, подпись и значение
    component InfoRow: Rectangle {
        id: infoRow

        property string icon: ""
        property string label: ""
        property string value: ""
        property bool tabular: false

        implicitHeight: Theme.dp(30)
        Layout.fillWidth: true
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            spacing: Theme.dp(8)

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Theme.dp(24)
                implicitHeight: Theme.dp(24)
                radius: Theme.rad(7)
                color: Theme.bgTrack

                Icon {
                    anchors.centerIn: parent
                    name: infoRow.icon
                    size: Theme.dp(14)
                    color: Theme.subtext
                }
            }

            LText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                elide: Text.ElideRight
                role: "bodySmall"
                color: Theme.subtext
                text: infoRow.label
            }

            LText {
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: Theme.dp(180)
                elide: Text.ElideRight
                role: "bodySmall"
                weight: 560
                tabular: infoRow.tabular
                color: Theme.text
                text: infoRow.value
            }
        }
    }
}
