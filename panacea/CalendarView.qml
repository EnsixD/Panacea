import QtQuick
import QtQuick.Layouts

// Календарь: сетка месяца, сегодняшний день подсвечен.
// Неделя начинается с понедельника.
Item {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    focus: true
    Component.onCompleted: forceActiveFocus()
    Keys.onEscapePressed: view.sys.page = "main"
    Keys.onLeftPressed:  view.shift(-1)
    Keys.onRightPressed: view.shift(1)

    readonly property date today: new Date()
    property int viewYear:  today.getFullYear()
    property int viewMonth: today.getMonth()          // 0..11

    function shift(delta) {
        var m = viewMonth + delta;
        var y = viewYear;
        while (m < 0)  { m += 12; y--; }
        while (m > 11) { m -= 12; y++; }
        viewMonth = m; viewYear = y;
    }
    function toToday() {
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
    }

    readonly property var monthsRu: ["Январь","Февраль","Март","Апрель","Май","Июнь",
                                     "Июль","Август","Сентябрь","Октябрь","Ноябрь","Декабрь"]
    readonly property var monthsEn: ["January","February","March","April","May","June",
                                     "July","August","September","October","November","December"]
    readonly property var dowRu: ["Пн","Вт","Ср","Чт","Пт","Сб","Вс"]
    readonly property var dowEn: ["Mo","Tu","We","Th","Fr","Sa","Su"]

    // 42 ячейки: шесть недель, чтобы сетка не прыгала между месяцами
    readonly property var cells: {
        var first = new Date(viewYear, viewMonth, 1);
        // getDay(): 0 — воскресенье; нам нужен понедельник первым
        var lead = (first.getDay() + 6) % 7;
        var start = new Date(viewYear, viewMonth, 1 - lead);
        var out = [];
        for (var i = 0; i < 42; i++) {
            var d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === viewMonth,
                isToday: d.getFullYear() === today.getFullYear()
                         && d.getMonth() === today.getMonth()
                         && d.getDate() === today.getDate(),
                weekend: i % 7 >= 5
            });
        }
        return out;
    }

    component NavBtn: Rectangle {
        property string sym: ""
        signal pressedAction()

        Layout.preferredWidth: 30
        Layout.preferredHeight: 30
        radius: 10
        color: navMa.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.06)
        Behavior on color { ColorAnimation { duration: 150 } }

        Text {
            anchors.centerIn: parent
            text: parent.sym
            color: view.sys.colMuted
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize }
        }
        MouseArea {
            id: navMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.pressedAction()
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            NavBtn { sym: "‹"; onPressedAction: view.shift(-1) }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: (view.sys.isEn ? view.monthsEn : view.monthsRu)[view.viewMonth]
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 2; bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: view.viewYear
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
            }

            NavBtn { sym: "›"; onPressedAction: view.shift(1) }
        }

        // дни недели
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: view.sys.isEn ? view.dowEn : view.dowRu
                Text {
                    required property int index
                    required property string modelData
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: index >= 5 ? Qt.rgba(1, 0.42, 0.42, 0.55) : view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4; bold: true }
                }
            }
        }

        // сетка месяца
        GridLayout {
            Layout.fillWidth: true
            columns: 7
            rowSpacing: 4
            columnSpacing: 4

            Repeater {
                model: view.cells

                Rectangle {
                    id: cell
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 10
                    color: cell.modelData.isToday
                           ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                           : (cellMa.containsMouse && cell.modelData.inMonth
                              ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                    border.color: cell.modelData.isToday ? view.sys.colOn : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 140 } }

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.day
                        color: !cell.modelData.inMonth ? Qt.rgba(1, 1, 1, 0.18)
                             : cell.modelData.isToday  ? view.sys.colFg
                             : cell.modelData.weekend  ? Qt.rgba(1, 0.42, 0.42, 0.85)
                                                       : view.sys.colFg
                        font {
                            family: view.sys.fontFam
                            pixelSize: view.sys.fontSize - 2
                            bold: cell.modelData.isToday
                        }
                    }

                    MouseArea {
                        id: cellMa
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }
            }
        }

        // возврат к текущему месяцу
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 118
            Layout.preferredHeight: 28
            radius: 10
            visible: view.viewMonth !== view.today.getMonth()
                     || view.viewYear !== view.today.getFullYear()
            color: todayMa.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.06)
            Behavior on color { ColorAnimation { duration: 150 } }
            Text {
                anchors.centerIn: parent
                text: view.sys.tr("Сегодня")
                color: view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
            }
            MouseArea {
                id: todayMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: view.toToday()
            }
        }
    }
}
