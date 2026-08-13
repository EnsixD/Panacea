import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Задачи на рабочем столе — первый плагин.
//
// Маленький блокнот, который лежит на обоях: задачи собраны в разделы
// («Fix», «Дом», что угодно), внутри раздела нумеруются по порядку. Когда
// отмечены все задачи раздела, он и сам считается сделанным — но удалить его
// можно в любой момент, доделанным или нет: список дел, который нельзя
// вычеркнуть, быстро перестают вести.
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

    // ------------------------------------------------------------- вид
    implicitWidth: todo.sys.cfg.todoW
    implicitHeight: todo.sys.cfg.todoH

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: Qt.rgba(todo.sys.colBg.r, todo.sys.colBg.g, todo.sys.colBg.b, 0.92)
        border.width: 1
        border.color: Qt.rgba(todo.sys.colFg.r, todo.sys.colFg.g, todo.sys.colFg.b, 0.12)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // --------------------------------------------- панель переноса
            // Пока блокнот не приколот, за эту полосу его таскают. Пипетка
            // прибивает его там, где он оказался, и полоса гаснет — но
            // остаётся на месте, чтобы открепить было чем.
            Item {
                id: dragBar
                Layout.fillWidth: true
                Layout.preferredHeight: 18

                RowLayout {
                    anchors.fill: parent
                    spacing: 6

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 3
                        Layout.alignment: Qt.AlignVCenter
                        radius: 2
                        color: todo.sys.cfg.todoPinned
                               ? Qt.rgba(1, 1, 1, 0.10)
                               : (dragMa.containsMouse || dragMa.pressed
                                  ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.20))
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: todo.sys.tr("Задачи")
                        color: todo.sys.colMuted
                        elide: Text.ElideRight
                        font { family: todo.sys.fontBody; pixelSize: todo.sys.fontSize - 4 }
                    }

                    // пипетка: прикалывает блокнот к месту и отпускает обратно
                    Text {
                        text: "󰐷"
                        color: todo.sys.cfg.todoPinned ? todo.sys.colOn
                             : (pinMa.containsMouse ? todo.sys.colFg : todo.sys.colMuted)
                        font { family: todo.sys.fontFam; pixelSize: todo.sys.fontSize - 2 }
                        Behavior on color { ColorAnimation { duration: 140 } }

                        MouseArea {
                            id: pinMa
                            anchors.fill: parent
                            anchors.margins: -5
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                todo.sys.cfg.todoPinned = !todo.sys.cfg.todoPinned;
                                todo.sys.saveCfg();
                            }
                        }
                    }
                }

                MouseArea {
                    id: dragMa
                    anchors.fill: parent
                    // пипетка сверху, ей нажатие нужнее
                    anchors.rightMargin: 22
                    enabled: !todo.sys.cfg.todoPinned
                    hoverEnabled: true
                    cursorShape: enabled ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                                         : Qt.ArrowCursor

                    property real grabX: 0
                    property real grabY: 0

                    onPressed: mouse => {
                        dragMa.grabX = mouse.x;
                        dragMa.grabY = mouse.y;
                    }
                    onPositionChanged: mouse => {
                        if (!dragMa.pressed) return;
                        var p = todo.mapToItem(null, mouse.x, mouse.y);
                        // Держим блокнот в пределах экрана: утащенный за край
                        // он остался бы там навсегда — вернуть его нечем.
                        var w = todo.parent ? todo.parent.width : 0;
                        var h = todo.parent ? todo.parent.height : 0;
                        var nx = p.x - dragMa.grabX;
                        var ny = p.y - dragMa.grabY;
                        todo.sys.cfg.todoX = Math.max(0, Math.min(w - todo.width, nx));
                        todo.sys.cfg.todoY = Math.max(0, Math.min(h - todo.height, ny));
                    }
                    onReleased: todo.sys.saveCfg()
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

                                    Text {
                                        Layout.alignment: Qt.AlignTop
                                        text: "×"
                                        visible: rowHover.hovered
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
