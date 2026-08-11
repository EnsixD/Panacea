import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io

// Выбор темы: сетка карточек с превью обоев.
// Раньше это был список в tofi — единственное окно, выпадавшее из стиля.
Item {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    // список в одну колонку: вверх-вниз двигают выбор
    readonly property int columns: 1
    property int current: 0

    focus: true
    Component.onCompleted: { reload(); forceActiveFocus(); }
    Keys.onEscapePressed: view.sys.collapse()
    Keys.onLeftPressed:  view.move(-1)
    Keys.onRightPressed: view.move(1)
    Keys.onUpPressed:    view.move(-view.columns)
    Keys.onDownPressed:  view.move(view.columns)
    Keys.onReturnPressed: view.activateCurrent()
    Keys.onEnterPressed:  view.activateCurrent()
    Keys.onSpacePressed:  view.activateCurrent()

    function move(delta) {
        if (themes.count === 0) return;
        var i = view.current + delta;
        if (i < 0 || i >= themes.count) return;
        view.current = i;
    }
    function activateCurrent() {
        if (view.current < 0 || view.current >= themes.count) return;
        var t = themes.get(view.current);
        if (!t.tActive) view.apply(t.tName);
    }

    ListModel { id: themes }
    property string applying: ""

    Process {
        id: pList
        command: ["sh", "-c", view.sys.scriptDir + "/themes.sh list"]
        // Собираем весь список и заполняем модель разом: при построчном
        // append карточки досыпались уже после открытия и панель дёргалась.
        stdout: StdioCollector {
            onStreamFinished: {
                themes.clear();
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split("|");
                    if (p.length < 3) continue;
                    themes.append({
                        tName: p[0],
                        tWall: p[1],
                        tActive: p[2] === "yes",
                        tCustom: p.length > 3 && p[3] === "yes"
                    });
                    if (p[2] === "yes") view.current = themes.count - 1;
                }
            }
        }
    }
    Process {
        id: pSet
        onRunningChanged: {
            if (running) return;
            view.applying = "";
            // Список НЕ перечитываем: reload() очищал модель, панель на кадр
            // схлопывалась до нуля и разъезжалась заново — со стороны это
            // выглядело как повторное открытие прямо перед закрытием.
            // Тема уже применена, а при следующем открытии список соберётся
            // заново сам.
            fadeOut.restart();
        }
    }
    Timer {
        id: fadeOut
        interval: 120
        onTriggered: { view.sys.endThemeFade(); closeAfter.restart(); }
    }
    Timer {
        id: closeAfter
        interval: 380
        onTriggered: view.sys.collapse()
    }

    function reload() {
        themes.clear();
        pList.running = false;
        pList.running = true;
    }
    function apply(name) {
        view.applying = name;
        // снимок нынешних обоев ДО запуска скрипта: после него на диске
        // уже новый путь и снимать будет нечего
        view.sys.startThemeFade();
        pSet.command = ["sh", "-c", view.sys.scriptDir + "/themes.sh set \"$1\"", "_", name];
        pSet.running = true;
    }

    // название темы в читаемом виде: dark_mountains -> Dark mountains
    function pretty(n) {
        var s = String(n).replace(/_/g, " ");
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 9

        RowLayout {
            Layout.fillWidth: true
            spacing: 9

            Text {
                text: view.sys.tr("Темы")
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 1; bold: true }
            }
            Text {
                Layout.fillWidth: true
                text: view.sys.tr("обои")
                color: Qt.rgba(1, 1, 1, 0.28)
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; italic: true }
            }
            Text {
                visible: view.applying.length > 0
                text: view.sys.tr("Применяю…")
                color: view.sys.colOn
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                opacity: view.applying.length > 0 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }
        }

        // Узкий список вместо сетки во весь экран: строка = маленькое превью
        // обоев плюс название. Пилюля остаётся пилюлей.
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(304, themes.count * 58)
            clip: true
            spacing: 6
            model: themes
            currentIndex: view.current
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 160

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { radius: 2; color: Qt.rgba(1, 1, 1, 0.22) }
            }

            delegate: Rectangle {
                id: row
                required property int    index
                required property string tName
                required property string tWall
                required property bool   tActive
                required property bool   tCustom

                readonly property bool isCurrent: view.current === row.index
                readonly property bool busy: view.applying === row.tName

                width: ListView.view.width
                height: 52
                radius: 13
                color: row.isCurrent || rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10)
                                                            : Qt.rgba(1, 1, 1, 0.05)
                border.color: row.tActive ? view.sys.colOn
                            : (row.isCurrent ? Qt.rgba(1, 1, 1, 0.28) : view.sys.colLine)
                border.width: row.tActive ? 2 : 1
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }
                scale: rowMa.pressed ? 0.985 : 1.0
                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 7
                    anchors.rightMargin: 12
                    spacing: 11

                    // маленькое превью обоев
                    Rectangle {
                        Layout.preferredWidth: 66
                        Layout.preferredHeight: 38
                        radius: 9
                        clip: true
                        color: "#000000"

                        Image {
                            id: thumb
                            anchors.fill: parent
                            // это уже готовая миниатюра из ~/.cache/panacea/thumbs
                            source: row.tWall.indexOf("/") === 0 ? "file://" + row.tWall : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                            }
                        }

                        // пока картинка грузится — мягкая пульсация вместо пустоты
                        Rectangle {
                            id: thumbPulse
                            anchors.fill: parent
                            visible: thumb.status === Image.Loading
                            color: Qt.rgba(1, 1, 1, 0.06)
                            // именно по id: внутри анимации parent — null,
                            // и привязка каждый раз падала в TypeError
                            SequentialAnimation on opacity {
                                running: thumbPulse.visible
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.35; duration: 620 }
                                NumberAnimation { to: 1.0;  duration: 620 }
                            }
                        }

                        // у темы без обоев (чёрная) — просто заливка
                        Text {
                            anchors.centerIn: parent
                            visible: row.tWall.indexOf("/") !== 0
                            text: String.fromCodePoint(0xF03E4)
                            color: Qt.rgba(1, 1, 1, 0.25)
                            font { family: view.sys.fontFam; pixelSize: 16 }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: view.pretty(row.tName)
                        color: row.tActive ? view.sys.colFg : view.sys.colMuted
                        elide: Text.ElideRight
                        font {
                            family: view.sys.fontFam
                            pixelSize: view.sys.fontSize - 2
                            bold: row.tActive
                        }
                    }

                    // корзина — только у своих обоев
                    Rectangle {
                        visible: row.tCustom && (rowMa.containsMouse || row.isCurrent)
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: 13
                        color: delMa.containsMouse ? view.sys.colCrit : Qt.rgba(1, 1, 1, 0.08)
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(0xF01B4)
                            color: delMa.containsMouse ? "#ffffff" : view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 12 }
                        }
                        MouseArea {
                            id: delMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.removeWall(row.tName, row.tActive)
                        }
                    }

                    // отметка активной темы; пока применяется — точка-пульс
                    Rectangle {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: 11
                        visible: row.tActive || row.busy
                        color: row.busy ? Qt.rgba(1, 1, 1, 0.12) : view.sys.colOn
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(row.busy ? 0xF0765 : 0xF012C)
                            color: row.busy ? view.sys.colMuted : "#ffffff"
                            font { family: view.sys.fontFam; pixelSize: 12 }
                            SequentialAnimation on opacity {
                                running: row.busy
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 480 }
                                NumberAnimation { to: 1.0; duration: 480 }
                            }
                            onVisibleChanged: if (!visible) opacity = 1
                        }
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    anchors.rightMargin: 44   // не перекрываем корзину
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: view.current = row.index
                    onClicked: if (!row.tActive) view.apply(row.tName)
                }
            }
        }

        // ---- строка «+»: добавить свои обои
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: 13
            color: addMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04)
            border.color: addMa.containsMouse ? view.sys.colOn : view.sys.colLine
            border.width: 1
            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on border.color { ColorAnimation { duration: 160 } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 8
                Text {
                    text: String.fromCodePoint(0xF0415)
                    color: addMa.containsMouse ? view.sys.colOn : view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 16 }
                }
                Text {
                    text: view.sys.tr("Свои обои")
                    color: addMa.containsMouse ? view.sys.colFg : view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
            }
            MouseArea {
                id: addMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: view.sys.startWallpaperPick()
            }
        }
    }

    function removeWall(name, wasActive) {
        run(["sh", "-c", view.sys.scriptDir + "/themes.sh del \"$1\"", "_", name]);
        // если удалили активные — падаем на первую оставшуюся тему
        delTimer.wasActive = wasActive;
        delTimer.restart();
    }
    Process { id: pDel }
    function run(cmd) { pDel.command = cmd; pDel.running = true; }
    Timer {
        id: delTimer
        property bool wasActive: false
        interval: 250
        onTriggered: {
            view.reload();
            if (wasActive && themes.count > 0) view.apply(themes.get(0).tName);
        }
    }

    // ---------------------------------------------- имя для новых обоев
    Process {
        id: pAdd
        onRunningChanged: if (!running) { view.sys.wallpaperPick = ""; view.reload(); }
    }
    function saveWall(name) {
        var n = String(name).trim();
        if (n.length === 0 || view.sys.wallpaperPick.length === 0) return;
        pAdd.command = ["sh", "-c",
            view.sys.scriptDir + "/themes.sh add \"$1\" \"$2\"", "_", n, view.sys.wallpaperPick];
        pAdd.running = true;
    }

    MouseArea {
        anchors.fill: parent
        z: 90
        visible: view.sys.wallpaperPick.length > 0
        onClicked: view.sys.cancelWallpaperPick()
    }
    Rectangle {
        z: 91
        visible: view.sys.wallpaperPick.length > 0
        anchors.centerIn: parent
        width: Math.min(420, parent.width - 24)
        implicitHeight: nameCol.implicitHeight + 36
        radius: 20
        color: Qt.rgba(0.04, 0.04, 0.05, 0.98)
        border.color: view.sys.colOn
        border.width: 1
        scale: view.sys.wallpaperPick.length > 0 ? 1 : 0.94
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: nameCol
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                radius: 12
                clip: true
                color: "#000000"
                Image {
                    anchors.fill: parent
                    source: view.sys.wallpaperPick.length
                            ? "file://" + view.sys.wallpaperPick : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            Text {
                text: view.sys.tr("Название обоев")
                color: view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 11
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.color: nameField.activeFocus ? view.sys.colOn : view.sys.colLine
                    border.width: 1
                    TextInput {
                        id: nameField
                        anchors.fill: parent
                        anchors.leftMargin: 13
                        anchors.rightMargin: 13
                        verticalAlignment: TextInput.AlignVCenter
                        color: view.sys.colFg
                        selectByMouse: true
                        focus: view.sys.wallpaperPick.length > 0
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1 }
                        onAccepted: view.saveWall(text)
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: nameField.text.length === 0
                            text: view.sys.tr("Например, Закат")
                            color: Qt.rgba(1, 1, 1, 0.28)
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1 }
                        }
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 96
                    Layout.preferredHeight: 40
                    radius: 11
                    color: nameField.text.trim().length
                           ? Qt.rgba(0.13, 0.77, 0.37, 0.28) : Qt.rgba(1, 1, 1, 0.06)
                    Text {
                        anchors.centerIn: parent
                        text: view.sys.tr("Сохранить")
                        color: nameField.text.trim().length ? "#22c55e" : view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.saveWall(nameField.text)
                    }
                }
            }
        }
    }
}
