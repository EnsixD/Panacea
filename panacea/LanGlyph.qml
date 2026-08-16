import QtQuick

// Значок проводной сети: три квадрата, соединённых деревом.
//
// Нарисован, а не взят из шрифта. Рисунок у готовых глифов Nerd Font тот
// же самый, но перекладина там шире самих квадратов и на этих размерах
// читается сплошной полосой поперёк значка. Толщину линий в глифе не
// поправить, это часть его формы, — а здесь перекладина идёт ровно от
// середины одного нижнего квадрата до середины другого.
//
// Ветки углом, а не наискось: наклонные пробовали, вышло хуже.
//
// Здесь толщина задаётся отдельно от размера, поэтому фигура остаётся
// разборчивой и в плитке быстрых настроек, и в свёрнутом острове, где она
// вдвое мельче. Заодно она чётко ложится на пиксели в любом масштабе, чего
// от шрифтового глифа на 15 пикселях не добиться.
Item {
    id: lan

    property color color: "#ffffff"
    // Толщина линий целым числом пикселей, а не долей высоты: дробная
    // обводка размазывается сглаживанием, и при размерах острова фигура из
    // тонких линий превращается в серое пятно. Порог подобран по двум
    // местам, где значок стоит: в плитке он крупный, в острове вдвое мельче.
    property real stroke: lan.height <= 20 ? 1 : 2

    implicitWidth: 18
    implicitHeight: 18

    // Квадраты одинаковой ширины: верхний по центру, два внизу по краям.
    // Ширина в две пятых значка — тогда между нижними остаётся просвет, и
    // перекладина видна как перекладина, а не как их общая крышка.
    readonly property real boxW: lan.width * 0.40
    readonly property real boxH: lan.height * 0.26

    // Верхний квадрат
    Rectangle {
        x: (lan.width - lan.boxW) / 2
        y: 0
        width: lan.boxW
        height: lan.boxH
        color: "transparent"
        border.color: lan.color
        border.width: lan.stroke
        radius: lan.stroke
    }

    // Отросток вниз от верхнего квадрата — вертикаль перевёрнутой Y
    Rectangle {
        x: (lan.width - lan.stroke) / 2
        y: lan.boxH
        width: lan.stroke
        height: lan.height / 2 - lan.boxH
        color: lan.color
    }

    // Перекладина. Идёт ровно от середины левого нижнего квадрата до
    // середины правого и не выходит за них: перехлёст и превращал бы её в
    // полосу поперёк значка.
    Rectangle {
        x: lan.boxW / 2 - lan.stroke / 2
        y: lan.height / 2 - lan.stroke / 2
        width: lan.width - lan.boxW + lan.stroke
        height: lan.stroke
        color: lan.color
    }

    // Спуски к нижним квадратам — концы перевёрнутой Y
    Repeater {
        model: [0, 1]
        Rectangle {
            required property int modelData
            x: modelData === 0 ? lan.boxW / 2 - lan.stroke / 2
                               : lan.width - lan.boxW / 2 - lan.stroke / 2
            y: lan.height / 2
            width: lan.stroke
            height: lan.height - lan.boxH - lan.height / 2
            color: lan.color
        }
    }

    // Нижние квадраты
    Repeater {
        model: [0, 1]
        Rectangle {
            required property int modelData
            x: modelData === 0 ? 0 : lan.width - lan.boxW
            y: lan.height - lan.boxH
            width: lan.boxW
            height: lan.boxH
            color: "transparent"
            border.color: lan.color
            border.width: lan.stroke
            radius: lan.stroke
        }
    }
}
