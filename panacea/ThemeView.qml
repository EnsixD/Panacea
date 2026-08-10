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

    readonly property int columns: 4
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
        onRunningChanged: if (!running) { view.applying = ""; view.reload(); }
    }

    function reload() {
        themes.clear();
        pList.running = false;
        pList.running = true;
    }
    function apply(name) {
        view.applying = name;
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
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: "Panacea"
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 5; bold: true }
            }
            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignBaseline
                text: view.sys.tr("обои")
                color: Qt.rgba(1, 1, 1, 0.28)
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; italic: true }
            }
            Text {
                visible: view.applying.length > 0
                text: view.sys.tr("Применяю…")
                color: view.sys.colOn
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: view.columns
            rowSpacing: 12
            columnSpacing: 12

            Repeater {
                model: themes

                Rectangle {
                    id: card
                    required property int    index
                    required property string tName
                    required property string tWall
                    required property bool   tActive
                    required property bool   tCustom

                    readonly property bool isCurrent: view.current === card.index

                    Layout.fillWidth: true
                    Layout.preferredHeight: 132
                    radius: 14
                    color: card.isCurrent ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                    Behavior on color { ColorAnimation { duration: 160 } }
                    border.color: card.tActive
                                  ? view.sys.colOn
                                  : (card.isCurrent || cardMa.containsMouse
                                     ? Qt.rgba(1, 1, 1, 0.35) : view.sys.colLine)
                    border.width: card.tActive ? 2 : (card.isCurrent ? 2 : 1)
                    Behavior on border.color { ColorAnimation { duration: 160 } }

                    scale: cardMa.pressed ? 0.96
                         : (cardMa.containsMouse || card.isCurrent ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6

                        // превью обоев
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 84
                            radius: 10
                            clip: true
                            color: "#000000"

                            Image {
                                id: thumb
                                anchors.fill: parent
                                // это уже готовая миниатюра из ~/.cache/panacea/thumbs
                                source: card.tWall.indexOf("/") === 0 ? "file://" + card.tWall : ""
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
                                anchors.fill: parent
                                visible: thumb.status === Image.Loading
                                color: Qt.rgba(1, 1, 1, 0.06)
                                SequentialAnimation on opacity {
                                    running: parent.visible
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.35; duration: 620 }
                                    NumberAnimation { to: 1.0;  duration: 620 }
                                }
                            }

                            // у темы без обоев (чёрная) — просто заливка
                            Text {
                                anchors.centerIn: parent
                                visible: card.tWall.indexOf("/") !== 0
                                text: String.fromCodePoint(0xF03E4)
                                color: Qt.rgba(1, 1, 1, 0.25)
                                font { family: view.sys.fontFam; pixelSize: 26 }
                            }

                            // отметка активной темы
                            Rectangle {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 6
                                width: 22; height: 22; radius: 11
                                visible: card.tActive
                                color: view.sys.colOn
                                Text {
                                    anchors.centerIn: parent
                                    text: String.fromCodePoint(0xF012C)
                                    color: "#ffffff"
                                    font { family: view.sys.fontFam; pixelSize: 12 }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: view.pretty(card.tName)
                            color: card.tActive ? view.sys.colFg : view.sys.colMuted
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            font {
                                family: view.sys.fontFam
                                pixelSize: view.sys.fontSize - 3
                                bold: card.tActive
                            }
                        }
                    }

                    // крестик удаления — только у своих обоев
                    Rectangle {
                        visible: card.tCustom && (cardMa.containsMouse || card.isCurrent)
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 6
                        width: 22; height: 22; radius: 11
                        color: delMa.containsMouse ? view.sys.colCrit : Qt.rgba(0, 0, 0, 0.55)
                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(0xF01B4)   // корзина
                            color: "#ffffff"
                            font { family: view.sys.fontFam; pixelSize: 11 }
                        }
                        MouseArea {
                            id: delMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.removeWall(card.tName, card.tActive)
                        }
                    }

                    MouseArea {
                        id: cardMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: { view.current = card.index; view.forceActiveFocus() }
                        onClicked: if (!card.tActive) view.apply(card.tName)
                    }
                }
            }

            // ---- карточка «+»: добавить свои обои
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 132
                radius: 14
                color: addMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04)
                border.color: addMa.containsMouse ? view.sys.colOn : view.sys.colLine
                border.width: 1
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }
                scale: addMa.pressed ? 0.96 : (addMa.containsMouse ? 1.03 : 1.0)
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: String.fromCodePoint(0xF0415)   // плюс
                        color: addMa.containsMouse ? view.sys.colOn : view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 30 }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: view.sys.tr("Свои обои")
                        color: view.sys.colMuted
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
        width: 420
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
