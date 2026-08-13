import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Обзор рабочих столов (Super+Tab).
//
// Превью не рисованные: каждое окно показывается живым кадром через
// ScreencopyView, поэтому в карточках продолжают идти видео и анимации.
// Геометрию окон берём из lastIpcObject — того же JSON, что отдаёт
// hyprctl clients, — и просто ужимаем её до размера карточки.
FocusScope {
    id: view
    property var sys

    // Без focus: true клавиатура остаётся у корня окна, и Enter в оверлее
    // просто никуда не приходил — стол не переключался.
    focus: true

    // Выбор храним по номеру стола, а не по индексу в списке: список
    // приходит асинхронно и на первом кадре ещё пустой, поэтому индекс,
    // посчитанный в onCompleted, указывал не туда — оверлей открывался
    // с выделенным вторым столом вместо текущего.
    property int currentWs: 0
    readonly property int current: {
        for (var i = 0; i < wsList.length; i++)
            if (wsList[i].id === view.currentWs) return i;
        return 0;
    }

    readonly property var mon: Hyprland.focusedMonitor
    readonly property real monW: mon ? mon.width : 1920
    readonly property real monH: mon ? mon.height : 1080

    // Столы по порядку номеров. Пустые тоже показываем: на них переходят
    // не реже, чем на занятые.
    readonly property var wsList: {
        var out = [];
        var all = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        for (var i = 0; i < all.length; i++) {
            var w = all[i];
            if (!w || w.id < 0) continue;      // спецстолы не показываем
            out.push(w);
        }
        out.sort(function (a, b) { return a.id - b.id; });
        return out;
    }

    Component.onCompleted: {
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
        // Стол, с которого открыли: пилюля знает его точно и без опроса —
        // она слушает события Hyprland постоянно.
        view.currentWs = view.sys.wsId;
        view.forceActiveFocus();
    }
    FocusGrabber { target: view }

    // ------------------------------------------------------------ клавиши
    function move(d) {
        if (wsList.length === 0) return;
        var i = Math.max(0, Math.min(wsList.length - 1, view.current + d));
        view.currentWs = wsList[i].id;
    }
    Keys.onLeftPressed:  view.move(-1)
    Keys.onRightPressed: view.move(1)
    Keys.onUpPressed:    view.move(-view.columns)
    Keys.onDownPressed:  view.move(view.columns)
    Keys.onEscapePressed: view.sys.closeOverview()
    Keys.onReturnPressed: view.pick(view.current)
    Keys.onEnterPressed:  view.pick(view.current)
    Keys.onSpacePressed:  view.pick(view.current)
    Keys.onTabPressed:    view.move(1)
    Keys.onBacktabPressed: view.move(-1)
    Keys.onPressed: event => {
        // цифрой — сразу на нужный стол
        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            var n = event.key - Qt.Key_0;
            for (var i = 0; i < view.wsList.length; i++) {
                if (view.wsList[i].id !== n) continue;
                view.pick(i);
                event.accepted = true;
                return;
            }
        }
    }

    // ------------------------------------------------------------- выбор
    // Своей анимации перехода тут нет: оверлей просто уходит, а стол
    // сменяется штатной прокруткой Hyprland — той же, что по Super+1 и жестам.
    function pick(i) {
        if (i < 0 || i >= wsList.length) return;
        view.currentWs = wsList[i].id;
        view.sys.gotoWorkspace(wsList[i].id);
        view.sys.closeOverview();
    }

    // ------------------------------------------------------------ раскладка
    readonly property int columns: Math.min(3, Math.max(1, wsList.length))
    // Карточка занимает столько, сколько влезает: и по ширине, и по высоте —
    // иначе на трёх столбцах нижний ряд уезжал за экран.
    readonly property real cardW: Math.min(
        (view.width - 140) / columns - 20,
        ((view.height - 210) / Math.max(1, Math.ceil(wsList.length / columns)) - 20)
            * (monW / monH))
    readonly property real cardH: cardW * (monH / monW)

    MouseArea {
        anchors.fill: parent
        onClicked: view.sys.closeOverview()
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 22

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: view.sys.tr("Рабочие столы")
            color: Qt.rgba(1, 1, 1, 0.55)
            font {
                family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2
                bold: true; capitalization: Font.AllUppercase; letterSpacing: 2
            }
        }

        GridLayout {
            id: grid
            Layout.alignment: Qt.AlignHCenter
            columns: view.columns
            rowSpacing: 20
            columnSpacing: 20

            Repeater {
                model: view.wsList

                Rectangle {
                    id: card
                    required property int index
                    required property var modelData

                    readonly property bool picked: view.current === card.index
                    readonly property bool live: view.sys.wsId === card.modelData.id

                    Layout.preferredWidth: view.cardW
                    Layout.preferredHeight: view.cardH
                    radius: 16
                    color: Qt.rgba(0.06, 0.06, 0.07, 0.92)
                    border.color: card.picked ? view.sys.colOn
                                : card.live ? Qt.rgba(1, 1, 1, 0.35)
                                            : Qt.rgba(1, 1, 1, 0.12)
                    border.width: card.picked ? 2 : 1
                    clip: true
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    scale: card.picked ? 1.04 : 1.0
                    Behavior on scale {
                        NumberAnimation { duration: 170; easing.type: Easing.OutBack }
                    }

                    // ---------------------------------------- окна стола
                    // Отдельный слой с отступом: у карточки скруглённые углы,
                    // и окно, лежащее вплотную к краю, срезалось ими.
                    Item {
                        id: winLayer
                        anchors.fill: parent
                        anchors.margins: 7

                    Repeater {
                        model: view.sys.overviewToplevels

                        Item {
                            id: win
                            required property var modelData
                            readonly property var geo: modelData.geo

                            visible: win.geo.ws === card.modelData.id
                            // Координаты окна в системе монитора ужимаем до
                            // карточки. Заголовок и рамки Hyprland сюда не
                            // входят — берём чистую геометрию клиента.
                            x: (win.geo.x - (view.mon ? view.mon.x : 0)) * winLayer.width / view.monW
                            y: (win.geo.y - (view.mon ? view.mon.y : 0)) * winLayer.height / view.monH
                            width:  win.geo.w * winLayer.width / view.monW
                            height: win.geo.h * winLayer.height / view.monH

                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.color: Qt.rgba(1, 1, 1, 0.10)
                                border.width: 1
                                clip: true

                                // Живой кадр окна: видео и анимации в превью
                                // продолжают идти, потому что это тот же
                                // буфер, а не снимок.
                                ScreencopyView {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    captureSource: win.modelData.wayland
                                    live: true
                                    paintCursor: false
                                    visible: hasContent
                                    // Кадр окна ужимается в разы, и без
                                    // сглаживания края текста рассыпались
                                    // в пиксельную кашу.
                                    smooth: true
                                    antialiasing: true
                                    layer.enabled: true
                                    layer.smooth: true
                                    layer.mipmap: true
                                }

                                // пока кадра нет — класс приложения текстом
                                Text {
                                    anchors.centerIn: parent
                                    visible: parent.children.length > 0
                                             && !parent.children[0].hasContent
                                    text: String(win.geo.cls || "")
                                    color: Qt.rgba(1, 1, 1, 0.45)
                                    elide: Text.ElideRight
                                    width: parent.width - 12
                                    horizontalAlignment: Text.AlignHCenter
                                    font { family: view.sys.fontFam; pixelSize: 11 }
                                }
                            }
                        }
                    }

                    }

                    // ------------------------------------------ подпись
                    Rectangle {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        width: wsNum.implicitWidth + 18
                        height: 24
                        radius: 12
                        color: card.picked
                               ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g,
                                         view.sys.colOn.b, 0.85)
                               : Qt.rgba(0, 0, 0, 0.6)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            id: wsNum
                            anchors.centerIn: parent
                            text: card.modelData.name
                            color: "#ffffff"
                            font {
                                family: view.sys.fontFam; pixelSize: 12
                                bold: card.picked || card.live
                            }
                        }
                    }

                    // точка «здесь вы сейчас»
                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        width: 8; height: 8; radius: 4
                        visible: card.live
                        color: view.sys.colOk
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: view.currentWs = card.modelData.id
                        onClicked: view.pick(card.index)
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: view.sys.tr("Стрелки — выбрать · Enter — перейти · Esc — закрыть")
            color: Qt.rgba(1, 1, 1, 0.30)
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
        }
    }

}
