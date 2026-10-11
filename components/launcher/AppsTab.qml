import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// Вкладка «Приложения»: фильтр по name/comment/keywords, закреплённые вперёд,
// запуск по клику или Enter. Логика перенесена из прежнего Launcher.
Item {
    id: root

    property string query: ""
    property int sel: 0
    property var shell: null

    signal hovered(int index)

    readonly property var apps: {
        const q = root.query.toLowerCase().trim();
        const out = [];
        for (const a of DesktopEntries.applications.values) {
            if (a.noDisplay) continue;
            if (Apps.isHidden(a) && !Apps.showHidden) continue;
            const name = (a.name || "").toLowerCase();
            const comment = (a.comment || "").toLowerCase();
            const kwSrc = Array.isArray(a.keywords) ? a.keywords.join(" ") : (a.keywords || "");
            const kw = String(kwSrc).toLowerCase();
            if (q === "" || name.includes(q) || comment.includes(q) || kw.includes(q)) out.push(a);
        }
        out.sort((x, y) => {
            const px = Apps.isPinned(x), py = Apps.isPinned(y);
            if (px !== py) return px ? -1 : 1;
            return (x.name || "").localeCompare(y.name || "");
        });
        return out.slice(0, 60);
    }
    // ── калькулятор: строка «= результат» над приложениями ────────────
    // экранирование одинарных кавычек для sh
    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    // «математическая» строка: только цифры, операторы и скобки,
    // обязательно есть цифра и хотя бы один оператор
    readonly property string calcResult: {
        const q = root.query.trim();
        if (q === "" || !/^[0-9+\-*/().,%^ ]+$/.test(q)) return "";
        if (!/[0-9]/.test(q)) return "";
        if (!/[+\-*/%^]/.test(q)) return "";
        return root.calcEval(q);
    }
    readonly property var calcRow: ({
        calc: true,
        name: "= " + root.calcResult,
        comment: "Скопировать результат",
        icon: "calculate"
    })
    // модель списка: псевдо-строка калькулятора + приложения
    readonly property var rows: root.calcResult !== "" ? [root.calcRow].concat(root.apps) : root.apps
    readonly property int count: root.rows.length

    implicitHeight: Theme.dp(400)

    function activate(index) {
        // индекс 0 занят строкой калькулятора — копируем результат
        if (root.calcResult !== "" && index === 0) {
            Quickshell.execDetached(["sh", "-c", "printf %s " + root.shq(root.calcResult) + " | wl-copy"]);
            if (root.shell) root.shell.closeOverlays();
            return;
        }
        const a = root.rows[index];
        if (!a) return;
        let cmd = a.command;
        if (typeof cmd === "string") cmd = ["sh", "-c", cmd];
        Quickshell.execDetached(cmd);
        if (root.shell) root.shell.closeOverlays();
    }

    // ── упрощённый вычислитель (порт luciddocks/DockCalc.qml) ─────────
    // только числа и операторы + - * / % ^, унарный минус, скобки,
    // степень право-ассоциативна; на любой мусор/NaN/∞ — пусто
    function calcTokenize(src) {
        var out = [];
        var i = 0;
        while (i < src.length) {
            var ch = src.charAt(i);
            if (ch === " " || ch === "\t" || ch === ",") { i++; continue; }
            if ((ch >= "0" && ch <= "9") || ch === ".") {
                var s = i;
                while (i < src.length && ((src.charAt(i) >= "0" && src.charAt(i) <= "9") || src.charAt(i) === ".")) i++;
                var n = parseFloat(src.substring(s, i));
                if (isNaN(n)) return null;
                out.push({ t: "num", v: n });
                continue;
            }
            if ("+-*/%^()".indexOf(ch) !== -1) { out.push({ t: ch, v: ch }); i++; continue; }
            return null;
        }
        return out;
    }
    function calcParseExpr(tk, p) {
        var left = root.calcParseTerm(tk, p);
        if (!left) return null;
        while (left.next < tk.length && (tk[left.next].t === "+" || tk[left.next].t === "-")) {
            var op = tk[left.next].t;
            var right = root.calcParseTerm(tk, left.next + 1);
            if (!right) return null;
            left = { value: op === "+" ? left.value + right.value : left.value - right.value, next: right.next };
        }
        return left;
    }
    function calcParseTerm(tk, p) {
        var left = root.calcParsePower(tk, p);
        if (!left) return null;
        while (left.next < tk.length && (tk[left.next].t === "*" || tk[left.next].t === "/" || tk[left.next].t === "%")) {
            var op = tk[left.next].t;
            var right = root.calcParsePower(tk, left.next + 1);
            if (!right) return null;
            var v = op === "*" ? left.value * right.value : (op === "/" ? left.value / right.value : left.value % right.value);
            left = { value: v, next: right.next };
        }
        return left;
    }
    function calcParsePower(tk, p) {
        var base = root.calcParseUnary(tk, p);
        if (!base) return null;
        if (base.next < tk.length && tk[base.next].t === "^") {
            var exp = root.calcParsePower(tk, base.next + 1);
            if (!exp) return null;
            return { value: Math.pow(base.value, exp.value), next: exp.next };
        }
        return base;
    }
    function calcParseUnary(tk, p) {
        if (p < tk.length && (tk[p].t === "-" || tk[p].t === "+")) {
            var sign = tk[p].t === "-" ? -1 : 1;
            var inner = root.calcParseUnary(tk, p + 1);
            if (!inner) return null;
            return { value: sign * inner.value, next: inner.next };
        }
        return root.calcParsePrimary(tk, p);
    }
    function calcParsePrimary(tk, p) {
        if (p >= tk.length) return null;
        var t = tk[p];
        if (t.t === "num") return { value: t.v, next: p + 1 };
        if (t.t === "(") {
            var inner = root.calcParseExpr(tk, p + 1);
            if (!inner || inner.next >= tk.length || tk[inner.next].t !== ")") return null;
            return { value: inner.value, next: inner.next + 1 };
        }
        return null;
    }
    function calcEval(src) {
        var tk = root.calcTokenize(src);
        if (!tk || tk.length === 0) return "";
        var res = root.calcParseExpr(tk, 0);
        if (!res || res.next !== tk.length) return "";
        if (typeof res.value !== "number" || !isFinite(res.value)) return "";
        return root.calcFormat(res.value);
    }
    function calcFormat(v) {
        if (Math.abs(v) >= 1e15 || (v !== 0 && Math.abs(v) < 1e-6))
            return v.toExponential(6).replace(/e([+-])(\d)$/, "e$10$2");
        var r = Math.round(v * 1e10) / 1e10;
        var s = r.toString();
        if (s.indexOf(".") !== -1) s = s.replace(/0+$/, "").replace(/\.$/, "");
        return s;
    }

    onSelChanged: if (root.sel >= 0 && root.sel < appList.count) appList.positionViewAtIndex(root.sel, ListView.Contain)

    ListView {
        id: appList

        anchors.fill: parent
        model: root.rows
        clip: true
        spacing: Theme.dp(4)

        delegate: Item {
            id: rowItem

            required property var modelData
            required property int index

            width: appList.width
            height: Theme.dp(52)

            Rectangle {
                id: row

                width: parent.width
                height: Theme.dp(52)
                radius: Theme.radiusMd
                color: rowItem.index === root.sel ? Theme.accentContainer
                                                  : (rowMouse.containsMouse ? Theme.bgHover : "transparent")

                Behavior on color {
                    ColorAnimation { duration: Theme.durQuick }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.hovered(rowItem.index)
                    onClicked: root.activate(rowItem.index)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.dp(8)
                    anchors.rightMargin: Theme.dp(6)
                    spacing: Theme.dp(10)

                    // иконка приложения в контейнере с M3-радиусом
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: Theme.dp(40)
                        Layout.preferredHeight: Theme.dp(40)
                        radius: Theme.radiusMd
                        color: Theme.bgTrack
                        AppIcon {
                            anchors.centerIn: parent
                            visible: !rowItem.modelData.calc
                            size: 30
                            source: rowItem.modelData.icon ? Quickshell.iconPath(rowItem.modelData.icon, true) : ""
                        }
                        Icon {
                            anchors.centerIn: parent
                            visible: rowItem.modelData.calc === true
                            name: rowItem.modelData.icon || ""
                            size: 24
                            color: rowItem.index === root.sel ? Theme.fgAccentContainer : Theme.text
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: rowItem.modelData.name || ""
                            color: rowItem.index === root.sel ? Theme.fgAccentContainer : Theme.text
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodyLarge")
                            font.weight: Theme.typeWeight("bodyLarge")
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: rowItem.modelData.comment || ""
                            color: rowItem.index === root.sel ? Theme.fgAccentContainer : Theme.subtext
                            opacity: rowItem.index === root.sel ? 0.75 : 1
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodySmall")
                            font.weight: Theme.typeWeight("bodySmall")
                            elide: Text.ElideRight
                        }
                    }

                    // закрепить/открепить
                    IconButton {
                        Layout.alignment: Qt.AlignVCenter
                        visible: !rowItem.modelData.calc
                        icon: "push_pin"
                        variant: Apps.isPinned(rowItem.modelData) ? "filled" : "standard"
                        onClicked: Apps.togglePin(rowItem.modelData)
                    }

                    // скрыть/показать
                    IconButton {
                        Layout.alignment: Qt.AlignVCenter
                        visible: !rowItem.modelData.calc
                        icon: Apps.isHidden(rowItem.modelData) ? "visibility_off" : "visibility"
                        variant: Apps.isHidden(rowItem.modelData) ? "filled" : "standard"
                        onClicked: Apps.toggleHide(rowItem.modelData)
                    }
                }
            }
        }
    }

    Text { // пусто / нет результатов поиска
        anchors.centerIn: parent
        visible: appList.count === 0
        text: root.query.trim() !== "" ? "Ничего не найдено" : "Пусто"
        color: Theme.subtext
        font.family: Theme.textFont
        font.pixelSize: Theme.typeSize("bodyMedium")
        font.weight: Theme.typeWeight("bodyMedium")
    }
}
