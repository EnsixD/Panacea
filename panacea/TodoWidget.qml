import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Задачи — первый плагин. Вторая капсула у кромки экрана, рядом с островом.
//
// Задачи собраны в разделы («Fix», «Дом», что угодно), внутри раздела
// нумеруются по порядку. Когда отмечены все задачи раздела, он и сам
// считается сделанным — но удалить его можно в любой момент, доделанным или
// нет: список дел, который нельзя вычеркнуть, быстро перестают вести.
//
// Куда его поставить, решает настройка кромки, а не мышь: таскать окно по
// столу и потом искать, где оно осталось, — не то, чего ждут от оболочки,
// которая сама держит всё по краям.
//
// Записи лежат в ~/.local/share/panacea/todo.json, рядом с хранилищем
// паролей, а не в ~/.config: это то, что человек написал сам, и обновление
// оболочки не должно иметь к ним доступа.
Item {
    id: todo

    property var sys

    // ------------------------------------------------------------- данные
    // Формат: { "sections": [ { "name": "...", "tasks": [ {text, done} ] } ] }
    property var sections: []
    property bool loaded: false

    FileView {
        id: store
        path: Quickshell.env("HOME") + "/.local/share/panacea/todo.json"
        watchChanges: true
        // Файла нет, пока не записана первая задача, и это не ошибка.
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            var t = String(store.text()).trim();
            var data = [];
            try {
                var o = JSON.parse(t.length ? t : "{}");
                if (o && o.sections instanceof Array) data = o.sections;
            } catch (e) {
                // Разбитый файл не повод потерять всё: оставляем как есть на
                // диске и показываем пусто — перезапишется только по правке.
                data = [];
            }
            todo.sections = data;
            todo.loaded = true;
        }
        onLoadFailed: { todo.sections = []; todo.loaded = true; }
    }

    Process { id: pSave }
    function save() {
        if (!todo.loaded) return;   // не затираем файл до первого чтения
        var json = JSON.stringify({ sections: todo.sections });
        pSave.running = false;
        pSave.command = ["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\"",
            "_", store.path, json];
        pSave.running = true;
    }

    // Список меняем целиком: QML не замечает правку внутри уже лежащего
    // объекта, и половина строк осталась бы со старым видом.
    function commit(next) {
        todo.sections = next;
        todo.save();
    }
    function copy() { return JSON.parse(JSON.stringify(todo.sections)); }

    function addSection(name) {
        var n = String(name).trim();
        if (n.length === 0) return;
        var s = todo.copy();
        s.push({ name: n, tasks: [] });
        todo.commit(s);
    }
    function removeSection(i) {
        var s = todo.copy();
        s.splice(i, 1);
        todo.commit(s);
    }
    function addTask(i, text) {
        var t = String(text).trim();
        if (t.length === 0 || i < 0 || i >= todo.sections.length) return;
        var s = todo.copy();
        s[i].tasks.push({ text: t, done: false });
        todo.commit(s);
    }
    function toggleTask(i, j) {
        var s = todo.copy();
        s[i].tasks[j].done = !s[i].tasks[j].done;
        todo.commit(s);
    }
    function removeTask(i, j) {
        var s = todo.copy();
        s[i].tasks.splice(j, 1);
        todo.commit(s);
    }

    // Раздел сделан, когда сделаны все его задачи. Пустой — не сделан:
    // иначе только что заведённый раздел сразу выглядел бы выполненным.
    function sectionDone(sec) {
        if (!sec || !sec.tasks || sec.tasks.length === 0) return false;
        for (var i = 0; i < sec.tasks.length; i++)
            if (!sec.tasks[i].done) return false;
        return true;
    }

    // Сколько задач ещё не сделано — это всё, что видно в свёрнутом виде.
    readonly property int leftToDo: {
        var n = 0;
        for (var i = 0; i < todo.sections.length; i++) {
            var t = todo.sections[i].tasks || [];
            for (var j = 0; j < t.length; j++) if (!t[j].done) n++;
        }
        return n;
    }

    // ------------------------------------------------------------- вид
    // Ведёт себя как остров: свёрнут — короткая капсула со счётчиком, под
    // курсором разворачивается в список и складывается обратно, когда курсор
    // ушёл. Пока в поле ввода стоит курсор, не сворачивается: иначе строка
    // исчезала бы из-под рук на полуслове.
    property bool expanded: false

    HoverHandler { id: todoHover }
    onExpandedChanged: if (!todo.expanded) Qt.callLater(function () {
        // фокус уходит вместе со списком, иначе клавиатура остаётся у
        // невидимого поля и следующий набор улетает в никуда
        if (newSection) newSection.focus = false;
    })

    // Разворачивается сразу, как остров: задержка перед открытием читается
    // как задумчивость, а не как бережность.
    Timer {
        id: openTimer
        interval: 0
        onTriggered: if (todoHover.hovered) todo.expanded = true
    }
    Timer {
        id: closeTimer
        interval: 260
        onTriggered: {
            if (todoHover.hovered || todo.activeFocus) return;
            todo.expanded = false;
        }
    }
    Connections {
        target: todoHover
        function onHoveredChanged() {
            if (todoHover.hovered) { closeTimer.stop(); openTimer.restart(); }
            else                   { openTimer.stop(); closeTimer.restart(); }
        }
    }

    // Ширина одна на оба состояния — та, что задана в настройках: капсула,
    // меняющая ширину под курсором, ездила бы вбок вместе с островом, к
    // которому прижата. Разворот меняет только высоту.
    implicitWidth:  todo.sys.cfg.todoW
    implicitHeight: todo.expanded ? todo.sys.cfg.todoH : todo.sys.pillH

    Behavior on implicitHeight { NumberAnimation { duration: todo.sys.animMs; easing.type: Easing.InOutCubic } }

    // Форма островная: у прижатой кромки углы срезаны, у смотрящей в экран —
    // скруглены. Так блокнот выглядит выросшим из края, а не положенным
    // сверху. Оторванный от кромки (islandGap) круглый со всех сторон.
    readonly property bool atTop:    todo.sys.cfg.todoPos === "top"
    readonly property bool atBottom: todo.sys.cfg.todoPos === "bottom"
    readonly property bool atLeft:   todo.sys.cfg.todoPos === "left"
    readonly property bool atRight:  todo.sys.cfg.todoPos === "right"
    // у кромки углов нет вовсе: блокнот прижат к ней вплотную
    readonly property real edgeR: 0

    Rectangle {
        anchors.fill: parent
        clip: true
        // свободные от кромки углы у свёрнутой капсулы круглые целиком
        readonly property real freeR: todo.expanded ? 18 : todo.height / 2
        topLeftRadius:     todo.atTop || todo.atLeft  ? todo.edgeR : freeR
        topRightRadius:    todo.atTop || todo.atRight ? todo.edgeR : freeR
        bottomLeftRadius:  todo.atBottom || todo.atLeft  ? todo.edgeR : freeR
        bottomRightRadius: todo.atBottom || todo.atRight ? todo.edgeR : freeR
        Behavior on topLeftRadius     { NumberAnimation { duration: todo.sys.animMs } }
        Behavior on topRightRadius    { NumberAnimation { duration: todo.sys.animMs } }
        Behavior on bottomLeftRadius  { NumberAnimation { duration: todo.sys.animMs } }
        Behavior on bottomRightRadius { NumberAnimation { duration: todo.sys.animMs } }
        // Ни рамки, ни полупрозрачности: остров рисуется сплошным и без
        // границы, а рамка в один пиксель у прижатой кромки читалась как
        // щель между капсулой и краем экрана.
        color: todo.sys.colBg

        // --------------------------------------------------- свёрнутый вид
        // Разложено по ширине, как в свёрнутом острове: значок и подпись
        // слева, счёт справа. По центру два знака на всю капсулу смотрелись
        // бы потерянными.
        RowLayout {
            id: collapsed
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 8
            visible: !todo.expanded
            opacity: todo.expanded ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: todo.sys.animFast } }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: "󰄲"
                color: todo.sys.colOn
                font { family: todo.sys.fontFam; pixelSize: todo.sys.fontSize - 2 }
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: todo.sys.tr("Задачи")
                color: todo.sys.colMuted
                elide: Text.ElideRight
                font {
                    family: todo.sys.fontBody
                    pixelSize: todo.sys.fontSize - 3
                    bold: true
                    capitalization: Font.AllUppercase
                    letterSpacing: 1
                }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                // Ноль показываем галочкой: «0» рядом со значком читается как
                // «ноль задач заведено», а не «всё сделано».
                text: todo.leftToDo > 0 ? String(todo.leftToDo) : "󰄬"
                color: todo.leftToDo > 0 ? todo.sys.colFg : todo.sys.colOk
                font { family: todo.sys.fontFam; pixelSize: todo.sys.fontSize - 1; bold: true }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            visible: todo.expanded
            opacity: todo.expanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: todo.sys.animFast } }

            // ------------------------------------------------- заголовок
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "󰄲"
                    color: todo.sys.colOn
                    font { family: todo.sys.fontFam; pixelSize: todo.sys.fontSize - 3 }
                }

                Text {
                    Layout.fillWidth: true
                    text: todo.sys.tr("Задачи")
                    color: todo.sys.colMuted
                    elide: Text.ElideRight
                    font {
                        family: todo.sys.fontBody
                        pixelSize: todo.sys.fontSize - 4
                        bold: true
                        capitalization: Font.AllUppercase
                        letterSpacing: 1
                    }
                }
            }

            // --------------------------------------------------- разделы
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: list.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { radius: 2; color: Qt.rgba(1, 1, 1, 0.18) }
                }

                ColumnLayout {
                    id: list
                    width: parent.width
                    spacing: 10

                    Repeater {
                        model: todo.sections

                        ColumnLayout {
                            id: sec
                            required property int index
                            required property var modelData
                            readonly property bool done: todo.sectionDone(sec.modelData)

                            Layout.fillWidth: true
                            spacing: 3

                            // заголовок раздела
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: sec.done ? "󰄬" : "󰄱"
                                    color: sec.done ? todo.sys.colOk : todo.sys.colMuted
                                    font { family: todo.sys.fontFam; pixelSize: todo.sys.fontSize - 4 }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: sec.modelData.name
                                    color: sec.done ? todo.sys.colMuted : todo.sys.colFg
                                    elide: Text.ElideRight
                                    font {
                                        family: todo.sys.fontBody
                                        pixelSize: todo.sys.fontSize - 3
                                        bold: true
                                        capitalization: Font.AllUppercase
                                        letterSpacing: 0.8
                                    }
                                }

                                // Удалить можно всегда, а не только доделанный:
                                // раздел, от которого нельзя избавиться, висит
                                // укором и мешает вести остальные.
                                Text {
                                    text: "×"
                                    color: killMa.containsMouse ? todo.sys.colCrit : todo.sys.colMuted
                                    font { family: todo.sys.fontFam; pixelSize: todo.sys.fontSize }
                                    Behavior on color { ColorAnimation { duration: 140 } }

                                    MouseArea {
                                        id: killMa
                                        anchors.fill: parent
                                        anchors.margins: -5
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: todo.removeSection(sec.index)
                                    }
                                }
                            }

                            // задачи раздела
                            Repeater {
                                model: sec.modelData.tasks

                                RowLayout {
                                    id: task
                                    required property int index
                                    required property var modelData

                                    Layout.fillWidth: true
                                    Layout.leftMargin: 4
                                    spacing: 6

                                    // Номер, а не точка: по нему задачу
                                    // называют вслух и находят глазами.
                                    Text {
                                        Layout.alignment: Qt.AlignTop
                                        text: (task.index + 1) + "."
                                        color: todo.sys.colMuted
                                        font { family: todo.sys.fontFam; pixelSize: todo.sys.fontSize - 4 }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: task.modelData.text
                                        color: task.modelData.done ? todo.sys.colMuted : todo.sys.colFg
                                        wrapMode: Text.WordWrap
                                        font {
                                            family: todo.sys.fontBody
                                            pixelSize: todo.sys.fontSize - 3
                                            strikeout: task.modelData.done
                                        }
                                    }

                                    // Место под крестик держим всегда, а
                                    // показываем по наведению: пока он то
                                    // появлялся, то исчезал, строка каждый раз
                                    // пересчитывала ширину и текст дёргался.
                                    Text {
                                        Layout.alignment: Qt.AlignTop
                                        text: "×"
                                        opacity: rowHover.hovered ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                        color: taskKillMa.containsMouse ? todo.sys.colCrit
                                                                        : todo.sys.colMuted
                                        font { family: todo.sys.fontFam; pixelSize: todo.sys.fontSize - 3 }

                                        MouseArea {
                                            id: taskKillMa
                                            anchors.fill: parent
                                            anchors.margins: -5
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: todo.removeTask(sec.index, task.index)
                                        }
                                    }

                                    // Нажатие по строке отмечает и снимает.
                                    // Обработчики, а не MouseArea: область с
                                    // anchors внутри раскладки — неопределённое
                                    // поведение, о чём Qt честно предупреждает.
                                    HoverHandler {
                                        id: rowHover
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                    TapHandler {
                                        gesturePolicy: TapHandler.ReleaseWithinBounds
                                        onTapped: todo.toggleTask(sec.index, task.index)
                                    }
                                }
                            }

                            // новая задача в этот раздел
                            TextField {
                                Layout.fillWidth: true
                                Layout.leftMargin: 4
                                Layout.preferredHeight: 24
                                placeholderText: todo.sys.tr("+ задача")
                                color: todo.sys.colFg
                                placeholderTextColor: Qt.rgba(1, 1, 1, 0.25)
                                font { family: todo.sys.fontBody; pixelSize: todo.sys.fontSize - 3 }
                                background: Item {}
                                onAccepted: {
                                    todo.addTask(sec.index, text);
                                    text = "";
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        visible: todo.sections.length === 0
                        horizontalAlignment: Text.AlignHCenter
                        text: todo.sys.tr("Пока пусто. Заведите раздел ниже.")
                        color: Qt.rgba(1, 1, 1, 0.28)
                        wrapMode: Text.WordWrap
                        font { family: todo.sys.fontBody; pixelSize: todo.sys.fontSize - 4 }
                    }
                }
            }

            // --------------------------------------------- новый раздел
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                radius: 9
                color: Qt.rgba(1, 1, 1, 0.06)

                TextField {
                    id: newSection
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: Text.AlignVCenter
                    placeholderText: todo.sys.tr("+ раздел")
                    color: todo.sys.colFg
                    placeholderTextColor: Qt.rgba(1, 1, 1, 0.3)
                    font { family: todo.sys.fontBody; pixelSize: todo.sys.fontSize - 3 }
                    background: Item {}
                    onAccepted: {
                        todo.addSection(text);
                        text = "";
                    }
                }
            }
        }
    }
}
