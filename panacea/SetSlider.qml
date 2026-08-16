import QtQuick
import QtQuick.Layouts

// Ползунок с подписью сверху: слева название, справа значение с единицей,
// под ними — дорожка во всю ширину. Значение меняется и перетаскиванием,
// и одиночным щелчком по дорожке.
ColumnLayout {
    id: sl

    property var sys
    property string label: ""
    property real from: 0
    property real to: 100
    property real step: 1
    property real value: 0
    property string suffix: ""
    // сколько знаков после запятой показывать в значении
    property int decimals: 0
    // текст значения можно подменить целиком — например «выкл» на нуле
    property string valueText: sl.value.toFixed(sl.decimals) + (sl.suffix ? " " + sl.suffix : "")
    signal moved(real value)

    Layout.fillWidth: true
    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: sl.label
            color: sl.sys.colFg
            elide: Text.ElideRight
            font { family: sl.sys.fontBody; pixelSize: sl.sys.fontSize - 1 }
        }
        Text {
            text: sl.valueText
            color: sl.sys.colMuted
            font { family: sl.sys.fontBody; pixelSize: sl.sys.fontSize - 2 }
        }
    }

    Item {
        id: bar
        Layout.fillWidth: true
        implicitHeight: 18

        // Защита от деления на ноль, а не «не меньше единицы».
        //
        // Math.max(1, ...) ломал любой ползунок с диапазоном уже единицы:
        // прозрачность от 0.5 до 1.0 делилась на 1 вместо 0.5, и правый край
        // шкалы оказывался её серединой — ручка упиралась на половине пути и
        // дальше не шла. Досталось и приглушённому тексту с его 0.2…1.0.
        readonly property real span: Math.max(1e-6, sl.to - sl.from)
        readonly property real frac: Math.max(0, Math.min(1, (sl.value - sl.from) / span))

        function pick(px) {
            var f = Math.max(0, Math.min(1, px / Math.max(1, bar.width)));
            var raw = sl.from + f * span;
            var snapped = Math.round(raw / sl.step) * sl.step;
            sl.moved(Math.max(sl.from, Math.min(sl.to, snapped)));
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 6
            radius: 3
            color: Qt.rgba(sl.sys.colFg.r, sl.sys.colFg.g, sl.sys.colFg.b, 0.10)

            Rectangle {
                width: parent.width * bar.frac
                height: parent.height
                radius: parent.radius
                color: sl.sys.colOn
            }
        }

        // Кружок ручки не выходит за края дорожки: на минимуме и максимуме
        // он упирается в них, а не свисает половиной наружу.
        Rectangle {
            width: 14
            height: 14
            radius: 7
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(bar.width - width, bar.width * bar.frac - width / 2))
            color: sl.sys.colOn
            border.width: 2
            border.color: Qt.lighter(sl.sys.colOn, 1.6)
        }

        // Зона нажатия шире дорожки: попасть в шестипиксельную полоску
        // мышью тяжело. Координату переводим в систему дорожки — иначе
        // расширение сдвигало бы значение на свою же ширину.
        MouseArea {
            id: grab
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            // Перетаскивание ручки принадлежит ползунку целиком: без этого
            // прокрутка страницы отбирала жест на первом же вертикальном
            // дрожании руки, и ползунок замирал на месте.
            preventStealing: true
            onPressed: mouse => bar.pick(mouse.x + grab.x)
            onPositionChanged: mouse => { if (pressed) bar.pick(mouse.x + grab.x); }
        }
    }
}
