import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

// Лаунчер приложений: поиск, иконки, навигация стрелками, Enter — запуск.
// Живёт внутри той же пилюли, поэтому раскрывается той же анимацией.
//
// Корень именно FocusScope, а не Item: панель отдаёт фокус загруженному виду
// целиком, и обычный Item забирал бы его СЕБЕ, оставляя поле ввода мёртвым.
// Область фокуса переадресует его тому ребёнку, у которого focus: true.
FocusScope {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    property string query: ""
    property int index: 0
    readonly property int maxRows: 6

    // Недавно запущенные: список идентификаторов, свежие в начале.
    // Хранится в ~/.cache/panacea/recent-apps, поэтому переживает перезапуск.
    property var recent: []
    readonly property string recentFile:
        (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache"))
        + "/panacea/recent-apps"

    Process {
        id: pRecentRead
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null", "_", view.recentFile]
        running: true
        stdout: StdioCollector {
            onStreamFinished: view.recent = text.trim().split("\n").filter(x => x.length)
        }
    }
    Process { id: pRecentWrite }

    function rememberApp(app) {
        var id = String(app.id || app.name || "");
        if (!id.length) return;
        var list = view.recent.filter(x => x !== id);
        list.unshift(id);
        if (list.length > 20) list = list.slice(0, 20);
        view.recent = list;
        pRecentWrite.command = ["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\"; printf '%s' \"$2\" > \"$1\"",
            "_", view.recentFile, list.join("\n")];
        pRecentWrite.running = true;
    }

    function recentRank(app) {
        var i = view.recent.indexOf(String(app.id || app.name || ""));
        return i < 0 ? 999 : i;
    }

    // Свои строки лаунчера: не приложения из системы, а страницы острова.
    // Живут в общем списке и ищутся вместе со всем остальным — иначе про них
    // пришлось бы помнить отдельно.
    //
    // keys — то, по чему строка находится, помимо имени: и по-русски, и
    // по-английски, и по именам самих агентов, чтобы «claude» тоже приводил
    // сюда.
    readonly property var builtins: [{
        builtin: "agents",
        // Ключ для списка недавних задан явно и по-английски: он же имя строки
        // в файле, а имя переводится. Через язык интерфейса «Агенты» и «Agents»
        // стали бы двумя разными записями, и недавнее терялось при переключении.
        id: "panacea:agents",
        glyph: String.fromCodePoint(0xF1719),      // md-robot_outline
        name: view.sys.tr("Агенты"),
        genericName: view.sys.tr("Тарифы и лимиты установленных ИИ-агентов"),
        keys: "agents agent ai claude codex gemini copilot cursor limits usage plan "
              + "агенты агент лимиты тариф подписка нагрузка"
    }]

    // ------------------------------------------------- другие системы на диске
    // Появляются в списке только если они на машине действительно есть:
    // bootos.sh ищет их сам, и пустой ответ означает пустой список. На машине
    // с одной системой в лаунчере не будет ни одной такой строки — ни серой,
    // ни отключённой, никакой.
    //
    // Список не фиксирован двумя пунктами: сколько систем нашлось, столько
    // строк и появится.
    property var systems: []

    Process {
        id: pSystems
        command: ["sh", view.sys.scriptDir + "/bootos.sh", "list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                var lines = String(text).trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].split("|");
                    if (p.length < 3) continue;
                    out.push({
                        builtin: "bootos",
                        bootId: p[0],
                        // Недавние помнят систему по её идентификатору в
                        // загрузчике, а не по названию: название приходит от
                        // os-prober и меняется вместе с ним.
                        id: "panacea:bootos:" + p[0],
                        glyph: view.osGlyph(p[2]),
                        name: p[1],
                        genericName: view.sys.tr("Перезагрузиться в эту систему"),
                        keys: "reboot restart boot " + p[1].toLowerCase() + " " + p[2]
                              + " перезагрузка загрузиться система"
                    });
                }
                view.systems = out;
            }
        }
    }

    function osGlyph(kind) {
        switch (String(kind)) {
        case "windows": return String.fromCodePoint(0xF05B3);   // md-microsoft_windows
        case "linux":   return String.fromCodePoint(0xF033D);   // md-linux
        case "mac":     return String.fromCodePoint(0xF0035);   // md-apple
        }
        return String.fromCodePoint(0xF02CA);                   // md-harddisk
    }

    function bootInto(app) {
        // Сам запуск живёт в корне оболочки, а не здесь. Лаунчер закрывается
        // следующей строкой, и всё, что объявлено в нём, уничтожается вместе с
        // видом — pkexec не успевал даже показать окно с паролем.
        //
        // Пароль здесь заодно и есть подтверждение: перезагрузка необратима, а
        // отдельного «вы уверены?» на пути к ней быть не должно — человек
        // попросил перезагрузиться, а не поговорить об этом.
        sys.bootIntoSystem(app.bootId);
        sys.closeLauncher();
    }

    // Всё, что лаунчер показывает помимо приложений.
    readonly property var extras: view.builtins.concat(view.systems)

    function builtinMatches(b, q) {
        if (q.length === 0) return false;   // с пустым запросом список — приложения
        if (String(b.name).toLowerCase().indexOf(q) >= 0) return true;
        return String(b.keys).toLowerCase().indexOf(q) >= 0;
    }

    // Отбор и сортировка: сперва совпадения с начала имени, потом остальные.
    readonly property var results: {
        var q = query.trim().toLowerCase();
        var all = DesktopEntries.applications ? DesktopEntries.applications.values : [];
        var starts = [], contains = [];
        // Свои строки держим отдельным списком, а не в starts: тот в конце
        // сортируется по алфавиту, и «Агенты» уехали бы в середину выдачи.
        // Их спрашивают по имени, прицельно, поэтому место у них первое.
        var pinned = [];
        for (var b = 0; b < view.extras.length; b++) {
            var bi = view.extras[b];
            // С пустым запросом своя строка идёт в общий список и встаёт по
            // давности наравне с приложениями: открыли её последней — она и
            // первая. С запросом место у неё всегда первое.
            //
            // Кроме систем: их в списке «всё подряд» нет вовсе. Там их строка
            // стояла бы вплотную к браузеру, и промах по Enter уводил бы в
            // перезагрузку. Систему вызывают намеренно, набрав её имя.
            if (q.length === 0) { if (bi.builtin !== "bootos") starts.push(bi); }
            else if (view.builtinMatches(bi, q)) pinned.push(bi);
        }
        for (var i = 0; i < all.length; i++) {
            var a = all[i];
            if (!a || a.noDisplay) continue;
            var n = String(a.name || "").toLowerCase();
            if (q.length === 0) { starts.push(a); continue; }
            var pos = n.indexOf(q);
            if (pos === 0) starts.push(a);
            else if (pos > 0) contains.push(a);
            else if (String(a.genericName || "").toLowerCase().indexOf(q) >= 0) contains.push(a);
        }
        var byName = function (x, y) {
            return String(x.name || "").localeCompare(String(y.name || ""));
        };
        // Пустой запрос — сверху то, что запускали недавно: курсор сразу
        // стоит на последнем открытом приложении.
        if (q.length === 0) {
            starts.sort(function (x, y) {
                var d = view.recentRank(x) - view.recentRank(y);
                return d !== 0 ? d : byName(x, y);
            });
            return starts;
        }
        starts.sort(byName); contains.sort(byName);
        return pinned.concat(starts, contains);
    }

    // ------------------------------------------------------------ калькулятор
    // Если в строке только числа и знаки — считаем и показываем ответ первым.
    // Enter копирует результат. Разрешён строго безопасный набор символов,
    // чтобы в вычисление не попало ничего постороннего.
    readonly property bool isMath: {
        var q = query.trim();
        if (q.length < 3) return false;
        if (!/[+\-*/^%]/.test(q)) return false;         // должен быть хоть один знак
        return /^[0-9\s+\-*/().,%^]+$/.test(q);
    }

    readonly property string mathResult: {
        if (!isMath) return "";
        try {
            var e = query.trim().replace(/,/g, ".").replace(/\^/g, "**");
            var r = Function('"use strict"; return (' + e + ')')();
            if (typeof r !== "number" || !isFinite(r)) return "";
            // убираем хвост из-за плавающей точки: 0.1+0.2 -> 0.3
            return String(parseFloat(r.toFixed(10)));
        } catch (err) {
            return "";
        }
    }

    Process { id: pCopyCalc }
    function copyResult() {
        if (mathResult.length === 0) return;
        pCopyCalc.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", mathResult];
        pCopyCalc.running = true;
        sys.closeLauncher();
    }

    onQueryChanged: index = 0
    onResultsChanged: if (index >= results.length) index = Math.max(0, results.length - 1)

    function launch() {
        if (view.mathResult.length > 0) { copyResult(); return; }
        var app = results[index];
        if (!app) return;
        // Свою строку не запускаем как программу — она открывает страницу
        // острова. Но в недавние попадает наравне с приложениями: её открыли
        // из того же списка и тем же Enter, и в следующий раз она должна
        // ждать сверху, а не на своём месте по алфавиту.
        if (app.builtin === "agents") { rememberApp(app); sys.openAgents(); return; }
        // Систему в недавние НЕ записываем. Недавние — это «чем я пользуюсь»,
        // а перезагрузка в другую систему случается раз в неделю и после неё
        // висела бы первой строкой в пустом лаунчере до конца времён. Причём
        // первой строкой, которую легче всего задеть случайным Enter.
        if (app.builtin === "bootos") { bootInto(app); return; }
        rememberApp(app);
        app.execute();
        sys.closeLauncher();
    }
    function move(delta) {
        if (results.length === 0) return;
        index = Math.max(0, Math.min(results.length - 1, index + delta));
        list.positionViewAtIndex(index, ListView.Contain);
    }

    // фокус сразу, плюс несколько повторов: слой получает клавиатуру
    // на кадр-другой позже создания компонента
    FocusGrabber { target: input }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 10

        // ------------------------------------------------------------ поиск
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: 13
            color: Qt.rgba(1, 1, 1, 0.06)
            border.color: input.activeFocus ? Qt.rgba(1, 1, 1, 0.22) : view.sys.colLine
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 13
                anchors.rightMargin: 13
                spacing: 9

                Text {
                    text: ""
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 14 }
                }
                TextField {
                    id: input
                    focus: true
                    Layout.fillWidth: true
                    placeholderText: view.sys.tr("Поиск приложений…")
                    color: view.sys.colFg
                    placeholderTextColor: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 13 }
                    background: null
                    onTextChanged: view.query = text

                    Keys.onDownPressed:   view.move(1)
                    Keys.onUpPressed:     view.move(-1)
                    Keys.onReturnPressed: view.launch()
                    Keys.onEnterPressed:  view.launch()
                    Keys.onEscapePressed: view.sys.closeLauncher()
                    Keys.onTabPressed:    view.move(1)
                }
                Text {
                    visible: view.results.length > 0
                    text: view.results.length
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 11 }
                }
            }
        }

        // ------------------------------------------------------------ список
        // результат вычисления — первой строкой
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            visible: view.mathResult.length > 0
            radius: 12
            color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.14)
            border.color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                Glyph {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    glyph: String.fromCodePoint(0xF00EC)
                    color: view.sys.colOn
                    fontFam: view.sys.fontFam
                    size: view.sys.iconSize - 2
                }
                Text {
                    Layout.fillWidth: true
                    text: view.mathResult
                    color: view.sys.colFg
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 3; bold: true }
                }
                Text {
                    text: "Enter"
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5 }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: view.copyResult()
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            visible: view.mathResult.length === 0
            Layout.preferredHeight: view.mathResult.length > 0 ? 0
                                  : Math.min(view.results.length, view.maxRows) * 46
            // Высоту анимирует капсула. Своя анимация здесь стартовала с нуля
            // и накладывалась на неё: панель сперва растягивалась, потом
            // «доразворачивалась» — те самые два этапа.
            clip: true
            model: view.results
            currentIndex: view.index
            boundsBehavior: Flickable.OvershootBounds
            flickDeceleration: 2200
            spacing: 2

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 3
                contentItem: Rectangle { radius: 2; color: Qt.rgba(1, 1, 1, 0.22) }
            }

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index

                width: list.width
                height: 44
                radius: 12
                color: index === view.index ? Qt.rgba(1, 1, 1, 0.11)
                     : (rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    spacing: 11

                    // иконка приложения из системной темы
                    Item {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26

                        Image {
                            id: appIcon
                            anchors.fill: parent
                            source: row.modelData.icon
                                    ? Quickshell.iconPath(row.modelData.icon, true) : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            sourceSize.width: 52
                            sourceSize.height: 52
                            visible: status === Image.Ready
                        }
                        // запасной значок, если иконки нет в теме
                        Rectangle {
                            anchors.fill: parent
                            visible: !appIcon.visible
                            radius: 7
                            color: Qt.rgba(1, 1, 1, 0.10)
                            // у своих строк иконки в теме нет и быть не может —
                            // рисуем глиф, а буквой обходятся только приложения
                            Glyph {
                                anchors.centerIn: parent
                                visible: String(row.modelData.glyph || "").length > 0
                                glyph: row.modelData.glyph || ""
                                color: view.sys.colFg
                                fontFam: view.sys.fontFam
                                size: 15
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: String(row.modelData.glyph || "").length === 0
                                text: String(row.modelData.name || "?").charAt(0).toUpperCase()
                                color: view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.name || ""
                            color: view.sys.colFg
                            elide: Text.ElideRight
                            font {
                                family: view.sys.fontFam
                                pixelSize: 13
                                bold: row.index === view.index
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: row.modelData.genericName || ""
                            color: view.sys.colMuted
                            elide: Text.ElideRight
                            font { family: view.sys.fontFam; pixelSize: 10 }
                        }
                    }

                    Text {
                        visible: row.index === view.index
                        text: "󰌑"
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 12 }
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: view.index = row.index
                    onClicked: view.launch()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: view.results.length === 0 && view.mathResult.length === 0
            text: view.sys.tr("Ничего не найдено")
            color: view.sys.colMuted
            horizontalAlignment: Text.AlignHCenter
            font { family: view.sys.fontFam; pixelSize: 11 }
        }
    }
}
