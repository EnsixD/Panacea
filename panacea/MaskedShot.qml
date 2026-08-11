import QtQuick
import QtQuick.Effects

// Содержимое, обрезанное по скруглённой маске.
//
// clip у Rectangle режет по его РАМКЕ, а не по радиусу: картинка внутри
// скруглённой карточки торчала острыми углами. Поэтому содержимое рисуется в
// невидимый слой (src), маска — второй слой со скруглённым белым
// прямоугольником (mask), а здесь они складываются.
MultiEffect {
    property Item src
    property Item mask

    source: shot.src
    maskEnabled: true
    maskSource: shot.mask

    // на себя ссылаемся по id: внутри привязок parent уже не тот
    id: shot
}
