import QtQuick
import QtQuick.Layouts

// Карточка раздела: тёмная плашка со скруглением, внутри — строки настроек.
// Разделительных линий между строками нет, ритм задаёт только шаг отступов.
Rectangle {
    id: card

    property var sys
    default property alias content: inner.data
    property alias spacing: inner.spacing
    property int pad: 16

    Layout.fillWidth: true
    implicitHeight: inner.implicitHeight + pad * 2
    radius: 18
    color: Qt.rgba(card.sys.colFg.r, card.sys.colFg.g, card.sys.colFg.b, 0.045)

    ColumnLayout {
        id: inner
        anchors.fill: parent
        anchors.margins: card.pad
        spacing: 14
    }
}
