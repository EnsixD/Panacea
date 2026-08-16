import QtQuick

// Значок проводной сети: три квадрата, соединённых перевёрнутой Y.
//
// Нарисован, а не взят из шрифта. У всех сетевых глифов Nerd Font
// соединитель один и тот же — отросток вниз и горизонтальная перекладина
// между нижними квадратами, — и на размерах острова эта перекладина шире
// самих квадратов и читается сплошной полосой поперёк значка. Толщину линий
// в глифе не поправить, это часть его формы.
//
// Ветки идут наискось от одной точки, а не углами через перекладину: угол
// даёт вилку о трёх зубьях, а нужна именно Y. Отсюда Canvas, а не
// прямоугольники: наклонную линию со сглаженными краями и скруглёнными
// концами прямоугольниками не сложить.
Canvas {
    id: lan

    property color color: "#ffffff"
    // Толщина линий целым числом пикселей: дробная размазывается
    // сглаживанием, и в острове, где значок вдвое мельче, фигура из тонких
    // линий превращается в серое пятно.
    property real stroke: lan.height <= 18 ? 1 : 2

    implicitWidth: 16
    implicitHeight: 16

    // Доли от размера значка. Квадраты чуть уже трети — тогда между нижними
    // остаётся просвет, и развилка видна как развилка.
    readonly property real boxW: 0.36
    readonly property real boxH: 0.26
    // где сходятся ветки: ниже середины, чтобы скос был заметно наклонным,
    // а не почти горизонтальным
    readonly property real forkY: 0.54

    onColorChanged:  requestPaint()
    onStrokeChanged: requestPaint()
    onWidthChanged:  requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();

        var w = lan.width, h = lan.height, s = lan.stroke;
        var bw = w * lan.boxW, bh = h * lan.boxH;
        var cx = w / 2;
        var fy = h * lan.forkY;

        ctx.strokeStyle = lan.color;
        ctx.lineWidth = s;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";

        // Обводка рисуется по средней линии, поэтому прямоугольники ужимаем
        // на половину толщины: иначе фигура вылезает за свои границы и в
        // плотном ряду задевает соседей.
        var o = s / 2;

        // верхний квадрат
        ctx.beginPath();
        ctx.rect(cx - bw / 2 + o, o, bw - s, bh - s);
        ctx.stroke();

        // отросток вниз до развилки
        ctx.beginPath();
        ctx.moveTo(cx, bh);
        ctx.lineTo(cx, fy);
        ctx.stroke();

        // две наклонные ветки к серединам нижних квадратов
        var lx = bw / 2 + o;
        var rx = w - bw / 2 - o;
        var by = h - bh;
        ctx.beginPath();
        ctx.moveTo(cx, fy);
        ctx.lineTo(lx, by);
        ctx.moveTo(cx, fy);
        ctx.lineTo(rx, by);
        ctx.stroke();

        // нижние квадраты
        ctx.beginPath();
        ctx.rect(o, by + o, bw - s, bh - s);
        ctx.rect(w - bw + o, by + o, bw - s, bh - s);
        ctx.stroke();
    }
}
