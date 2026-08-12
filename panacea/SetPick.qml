import QtQuick
import QtQuick.Layouts

// Выбор из длинного списка: шрифты, часовые пояса, форматы даты.
// Список раскрывается прямо в потоке страницы, а не всплывающим окном —
// всплывающее в прокручиваемой карточке пришлось бы возить за содержимым и
// оно всё равно обрезалось бы краем окна.
ColumnLayout {
    id: pick

    property var sys
    property string label: ""
    // список строк либо [{ id, text }]
    property var options: []
    property string value: ""
    property bool open: false
    // сколько строк видно до появления собственной прокрутки
    property int visibleRows: 7
    signal picked(string id)

    function idOf(o)   { return (o && o.id !== undefined) ? o.id : o; }
    function textOf(o) { return (o && o.text !== undefined) ? o.text : o; }
    function textFor(id) {
        for (var i = 0; i < pick.options.length; i++)
            if (idOf(pick.options[i]) === id) return textOf(pick.options[i]);
        return id;
    }

    Layout.fillWidth: true
    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: pick.label
            color: pick.sys.colFg
            elide: Text.ElideRight
            font { family: pick.sys.fontBody; pixelSize: pick.sys.fontSize - 1 }
        }

        Rectangle {
            Layout.preferredWidth: Math.min(260, Math.max(140, curText.implicitWidth + 44))
            Layout.preferredHeight: 30
            radius: 10
            color: headMa.containsMouse || pick.open
                   ? Qt.rgba(pick.sys.colFg.r, pick.sys.colFg.g, pick.sys.colFg.b, 0.12)
                   : Qt.rgba(pick.sys.colFg.r, pick.sys.colFg.g, pick.sys.colFg.b, 0.07)
            Behavior on color { ColorAnimation { duration: pick.sys.animFade } }

            Text {
                id: curText
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: chev.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: pick.textFor(pick.value)
                color: pick.sys.colFg
                elide: Text.ElideRight
                font { family: pick.sys.fontBody; pixelSize: pick.sys.fontSize - 3 }
            }

            Text {
                id: chev
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                // шеврон вверх, когда список раскрыт, и вниз, когда свёрнут
                text: String.fromCodePoint(pick.open ? 0xF0143 : 0xF0140)
                color: pick.sys.colMuted
                font { family: pick.sys.fontFam; pixelSize: pick.sys.fontSize - 2 }
            }

            MouseArea {
                id: headMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: pick.open = !pick.open
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: pick.open
            ? Math.min(pick.visibleRows, Math.max(1, pick.options.length)) * 28 + 12 : 0
        clip: true
        visible: Layout.preferredHeight > 0
        radius: 12
        color: Qt.rgba(pick.sys.colFg.r, pick.sys.colFg.g, pick.sys.colFg.b, 0.05)
        Behavior on Layout.preferredHeight {
            NumberAnimation { duration: pick.sys.animFade; easing.type: Easing.OutCubic }
        }

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 6
            clip: true
            model: pick.options
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: -1

            delegate: Rectangle {
                id: opt
                required property var modelData
                readonly property string oid: pick.idOf(opt.modelData)

                width: list.width
                height: 28
                radius: 8
                color: pick.value === opt.oid
                       ? Qt.rgba(pick.sys.colOn.r, pick.sys.colOn.g, pick.sys.colOn.b, 0.25)
                       : (optMa.containsMouse
                          ? Qt.rgba(pick.sys.colFg.r, pick.sys.colFg.g, pick.sys.colFg.b, 0.08)
                          : "transparent")

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    text: pick.textOf(opt.modelData)
                    color: pick.value === opt.oid ? pick.sys.colFg : pick.sys.colMuted
                    elide: Text.ElideRight
                    font { family: pick.sys.fontBody; pixelSize: pick.sys.fontSize - 3 }
                }

                MouseArea {
                    id: optMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { pick.picked(opt.oid); pick.open = false; }
                }
            }
        }
    }
}
