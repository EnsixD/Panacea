import QtQuick
import QtQuick.Layouts

// Макет рабочего стола для вкладки «Пилюля».
//
// Это не абстрактная схема, а тот же остров, что висит на экране: те же
// сегменты (день, часы, стол, раскладка, заряд), те же цвета из черновика и
// те же правила скругления. Фон — настоящие обои. Смысл в том, чтобы выбрать
// кромку и цвета, ни разу не применив настройки «на живом» экране.
Item {
    id: preview
    property var sys
    property var d                  // черновик оформления

    readonly property string pos: {
        var p = String(preview.d ? preview.d.pillPos : "top");
        return (p === "bottom" || p === "left" || p === "right") ? p : "top";
    }
    readonly property bool side: preview.pos === "left" || preview.pos === "right"

    // Во сколько раз макет меньше настоящего экрана. По нему считаются и
    // толщина острова, и размер текста — чтобы всё было 1:1, а не на глаз.
    // Цвета из черновика приходят СТРОКАМИ ("#ffffff"), и обращение вида
    // d.colFg.r давало undefined: Qt.rgba(undefined,…) — прозрачный цвет.
    // Именно поэтому день недели, раскладка и процент заряда были невидимы.
    // Здесь они один раз приводятся к настоящему color.
    readonly property color fgCol: preview.d ? preview.d.colFg : "#ffffff"
    readonly property color onCol: preview.d ? preview.d.colOn : "#3b82f6"

    readonly property real k: preview.sys && preview.sys.screen
            ? preview.height / Math.max(1, preview.sys.screen.height)
            : 0.4

    implicitHeight: 430

    Rectangle {
        id: screen
        anchors.centerIn: parent
        // пропорции настоящего экрана: иначе по макету не понять, насколько
        // остров длинный относительно кромки
        readonly property real ratio: preview.sys.screen
                ? preview.sys.screen.width / Math.max(1, preview.sys.screen.height)
                : 16 / 9
        height: preview.height
        width: Math.min(preview.width, height * ratio)
        radius: 14
        color: "#0b0f12"
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1

        // Всё содержимое — в маске со скруглением: clip у прямоугольника
        // режет по рамке, и обои торчали бы острыми углами.
        Item {
            id: deskShot
            anchors.fill: parent
            anchors.margins: 1
            visible: false
            layer.enabled: true

            Image {
                anchors.fill: parent
                source: preview.sys.currentWallThumb.length
                        ? "file://" + preview.sys.currentWallThumb : ""
                fillMode: Image.PreserveAspectCrop
                // декодируем под фактический размер макета (с запасом на
                // масштабирование), иначе обои выглядят пиксельными
                sourceSize.width: Math.max(1100, Math.round(deskShot.width * 1.4))
                asynchronous: true
                cache: true
            }
            // без обоев — хотя бы не пустота
            Rectangle {
                anchors.fill: parent
                visible: preview.sys.currentWallThumb.length === 0
                color: "#12181c"
            }

            // ------------------------------------------------- сам остров
            // Один и тот же компонент, что и в макете проводника: остров,
            // уголки примыкания и весь набор сегментов.
            PillMock {
                anchors.fill: parent
                sys: preview.sys
                pos: preview.pos
                fgCol: preview.fgCol
                onCol: preview.onCol
                k: preview.k
            }
        }

        Item {
            id: deskMask
            anchors.fill: parent
            anchors.margins: 1
            visible: false
            layer.enabled: true
            Rectangle {
                anchors.fill: parent
                radius: screen.radius - 1
                color: "#ffffff"
            }
        }

        MaskedShot {
            anchors.fill: parent
            anchors.margins: 1
            src: deskShot
            mask: deskMask
        }
    }
}
