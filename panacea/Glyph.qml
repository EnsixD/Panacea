import QtQuick

// Иконка Nerd Font, отцентрованная по фактическим границам рисунка.
//
// Обычный Text центрируется по своей рамке шириной в advance глифа. У иконок
// Material Design чернила шире advance и сидят в нём несимметрично: например,
// у шестерни при pixelSize 16 advance = 9.6, а сам рисунок 13 px шириной.
// Поэтому anchors.centerIn заметно уводит иконку вбок.
//
// TextMetrics отдаёт boundingRect и tightBoundingRect ОТНОСИТЕЛЬНО БАЗОВОЙ
// ЛИНИИ (y отрицательный вверх), а не относительно левого верхнего угла
// элемента. Пересчитываем в локальные координаты Text и совмещаем центр
// чернил с центром элемента.
Item {
    id: glyph

    property string glyph: ""
    property color color: "#ffffff"
    property string fontFam: "monospace"
    property real size: 16

    implicitWidth: size
    implicitHeight: size

    TextMetrics {
        id: tm
        font { family: glyph.fontFam; pixelSize: glyph.size }
        text: glyph.glyph
    }

    // базовая линия внутри рамки Text
    readonly property real baselineY: -tm.boundingRect.y
    // центр чернил в координатах Text
    readonly property real inkX: tm.tightBoundingRect.x + tm.tightBoundingRect.width / 2
    readonly property real inkY: baselineY + tm.tightBoundingRect.y
                                 + tm.tightBoundingRect.height / 2

    Text {
        text: glyph.glyph
        color: glyph.color
        font {
            family: glyph.fontFam; pixelSize: glyph.size
            // на мелких размерах глиф без хинтинга расплывается
            hintingPreference: Font.PreferFullHinting
        }

        // округляем позицию: на дробных координатах иконка размывается
        // по субпикселям и выглядит грязной
        x: Math.round(glyph.width  / 2 - glyph.inkX)
        y: Math.round(glyph.height / 2 - glyph.inkY)

        Behavior on color { ColorAnimation { duration: 160 } }
    }
}
