import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io

// Выбор обоев во весь экран: карусель, где выбранные обои стоят по центру,
// а соседние уходят по бокам вглубь. Раньше это был узкий список под пилюлей
// — картинку в нём было почти не видно, а выбирают обои всё-таки глазами.
//
// Ход каруселью считается в дробных «позициях» (pos): каждая карточка знает
// своё расстояние до центра и по нему сама решает, насколько уменьшиться,
// побледнеть и сдвинуть картинку внутри рамки. Последнее и даёт параллакс:
// рамка едет быстрее, чем её содержимое.
Item {
    id: view
    property var sys

    // дробная позиция карусели; целевая — target, между ними анимация
    property real pos: 0
    property int  target: 0
    Behavior on pos {
        NumberAnimation { duration: 420; easing.type: Easing.OutQuint }
    }
    onTargetChanged: view.pos = view.target

    property string applying: ""
    // обои, которые сейчас разлетаются во весь экран после выбора
    property string flying: ""
    // Миниатюра выбранных обоев: она уже декодирована, поэтому разворот
    // начинается с картинки, а не с чёрного прямоугольника.
    property string flyingThumb: ""
    // Листал ли человек сам. Пока нет — держим фокус на текущих обоях, даже
    // если список успел обновиться: открывая меню, ищут именно то, что стоит.
    property bool userScrolled: false

    // Вкладка: "still" — обычные обои, "live" — видео. Модель, скрипт и
    // подписи меняются вместе с ней, карусель остаётся той же.
    property string mode: "still"
    // Накопитель колеса: мышь и тачпад сыплют десятками мелких событий, и по
    // одной карточке на каждое лента пролетала мимо. Шагаем, только когда
    // накопилось на щелчок (120 единиц), и не чаще одного шага за паузу.
    property real wheelAcc: 0
    readonly property bool live: view.mode === "live"
    // Открыто ли меню. Отдельным свойством, а не прямо sys.wallsOpen: пока
    // выбранные обои вставляются, меню уже «закрыто» для анимаций, но окно
    // ещё живёт — иначе оно мигало обратно перед исчезновением.
    readonly property bool open: view.sys.wallsOpen && view.applying.length === 0

    readonly property int cardW: Math.round(Math.min(width * 0.44, 760))
    readonly property int cardH: Math.round(cardW * 9 / 16)
    // шаг между карточками: меньше ширины, поэтому соседи заглядывают из-за краёв
    readonly property real step: cardW * 0.62

    ListModel { id: walls }

    focus: true
    Component.onCompleted: {
        reload(); jumpToActive(); forceActiveFocus(); warmDelay.restart();
    }

    Keys.onEscapePressed: view.sys.closeWalls()
    Keys.onLeftPressed:   view.move(-1)
    Keys.onRightPressed:  view.move(1)
    Keys.onUpPressed:     view.move(-1)
    Keys.onDownPressed:   view.move(1)
    Keys.onReturnPressed: view.activate()
    Keys.onEnterPressed:  view.activate()
    Keys.onSpacePressed:  view.activate()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) { view.target = 0; event.accepted = true; }
        else if (event.key === Qt.Key_End) {
            view.target = Math.max(0, walls.count - 1); event.accepted = true;
        }
    }

    function move(d) {
        if (walls.count === 0) return;
        view.userScrolled = true;
        view.target = Math.max(0, Math.min(walls.count - 1, view.target + d));
    }
    function activate() {
        if (view.target < 0 || view.target >= walls.count) return;
        var w = walls.get(view.target);
        if (w.wActive) { view.sys.closeWalls(); return; }
        view.flyingThumb = w.wThumb;
        view.apply(w.wPath);
    }

    // Обновление модели на месте: совпавшие строки только правим, лишние
    // убираем с конца. Карточки не пересоздаются, поэтому картинки не мигают
    // и не грузятся заново, а прокрутка не сбрасывается на первые обои.
    function applyRows(rows, act) {
        var first = walls.count === 0;
        for (var i = 0; i < rows.length; i++) {
            if (i < walls.count) walls.set(i, rows[i]);
            else                 walls.append(rows[i]);
        }
        while (walls.count > rows.length) walls.remove(walls.count - 1);
        // Пока не листали — стоим на текущих обоях. Список обновляется и на
        // открытии, и после прогрева миниатюр, и раньше фокус после этого
        // уезжал в непонятное место.
        if ((first || !view.userScrolled) && act >= 0) {
            view.target = act;
            view.pos = act;
        } else if (view.target >= walls.count) {
            view.target = Math.max(0, walls.count - 1);
        }
    }

    // Список читает корень (sys.wallList / sys.liveList) — здесь только
    // раскладываем его в модель. Открытие поэтому мгновенное: данные уже есть.
    //
    // Режим можно передать явно. Это важно при переключении вкладки: внутри
    // обработчика onModeChanged привязка live ещё отдаёт ПРЕЖНЕЕ значение, и
    // список брался от старой вкладки — картинки на «живых» и наоборот.
    function reload(liveOverride) {
        var isLive = liveOverride === undefined ? view.live : liveOverride;
        var rows = (isLive ? view.sys.liveList : view.sys.wallList) || [];
        var act = -1;
        for (var i = 0; i < rows.length; i++) if (rows[i].wActive) act = i;
        view.applyRows(rows, act);
    }
    Connections {
        target: view.sys
        function onWallListChanged() { if (!view.live) view.reload(); }
        function onLiveListChanged() { if (view.live)  view.reload(); }
    }
    onModeChanged: {
        var isLive = view.mode === "live";
        view.userScrolled = false;
        view.reload(isLive);
        view.jumpToActive();
        if (isLive) liveWarmDelay.restart();
    }

    // Прогрев миниатюр для новых обоев — уже после того, как карусель
    // открылась и что-то показала. Когда закончит, перечитываем список: те
    // карточки, что грузились из исходников, переедут на миниатюры.
    Process {
        id: pWarm
        command: ["sh", "-c", view.sys.scriptDir + "/themes.sh warm"]
        // Пока идёт прогрев, подхватываем уже готовые миниатюры: ждать все
        // три сотни ffmpeg до первого обновления — это минуты.
        onRunningChanged: {
            if (running) warmPoll.restart();
            else { warmPoll.stop(); view.sys.refreshWalls(); }
        }
    }
    Timer {
        id: warmPoll
        interval: 2500
        repeat: true
        onTriggered: if (view.sys.wallsOpen) view.sys.refreshWalls();
                     else pWarm.running = false;
    }
    Timer {
        id: warmDelay
        interval: 900
        onTriggered: pWarm.running = true
    }

    // Постеры для видео: кадр из середины каждого. Тоже после открытия —
    // вытаскивать кадры из десятка файлов синхронно значит ждать.
    Process {
        id: pLiveWarm
        command: ["bash", Quickshell.env("HOME")
                          + "/.config/hypr/scripts/live_wallpaper.sh", "warm"]
        onRunningChanged: if (!running) view.sys.refreshLiveWalls()
    }
    Timer {
        id: liveWarmDelay
        interval: 700
        onTriggered: pLiveWarm.running = true
    }

    Process {
        id: pSet
        // Обои уже на месте: гасим кроссфейд и закрываем окно. Само
        // «applying» держим до конца — иначе меню на кадр показывалось
        // обратно перед закрытием.
        onRunningChanged: {
            if (running) return;
            view.sys.endThemeFade();
            closeAfter.restart();
        }
    }
    Timer {
        id: closeAfter
        // ждём, пока карточка докатится до кромок: закрыть раньше — и виден
        // скачок, окно исчезает посреди движения
        interval: 560
        onTriggered: view.sys.closeWalls()
    }
    // На каждое открытие встаём на текущие обои: возвращаться к тому месту,
    // где листали в прошлый раз, незачем — глазами ищут «а что стоит сейчас».
    // Состояние применения сбрасываем только когда окна уже не видно.
    Connections {
        target: view.sys
        function onWallsOpenChanged() {
            if (view.sys.wallsOpen) { view.userScrolled = false; view.jumpToActive(); }
            else                    resetAfterClose.restart();
        }
    }
    function jumpToActive() {
        for (var i = 0; i < walls.count; i++) {
            if (walls.get(i).wActive) { view.target = i; view.pos = i; return; }
        }
    }
    Timer {
        id: resetAfterClose
        interval: 400
        onTriggered: { view.applying = ""; view.flying = ""; view.flyingThumb = ""; }
    }

    // Применяем по полному пути, а не по имени: в подкаталогах обоев имена
    // повторяются, и по имени можно было поставить не ту картинку.
    function apply(path) {
        view.applying = path;
        view.flying = path;
        // снимок нынешних обоев ДО скрипта: после него на диске уже новый путь
        view.sys.startThemeFade();
        pSet.command = view.live
            ? ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/live_wallpaper.sh",
               "set", path]
            : ["sh", "-c", view.sys.scriptDir + "/themes.sh set \"$1\"", "_", path];
        pSet.running = true;
    }

    // имя в читаемом виде: dark_mountains -> Dark mountains
    function pretty(n) {
        var s = String(n).replace(/_/g, " ");
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    // Превращение острова в меню: подложка начинает ровно там, где висит
    // пилюля (она на это время спрятана), и растягивается до кромок. Поэтому
    // меню читается как развернувшийся остров, а не как отдельное окно.
    Rectangle {
        id: morph
        color: view.sys.colBg
        z: -1
        x:      view.open ? 0 : view.sys.pillRectX
        y:      view.open ? 0 : view.sys.pillRectY
        width:  view.open ? view.width  : Math.max(8, view.sys.pillRectW)
        height: view.open ? view.height : Math.max(8, view.sys.pillRectH)
        radius: view.open ? 0 : Math.min(width, height) / 2
        opacity: view.open ? 0.30 : 0.96
        visible: view.sys.wallsOpen

        Behavior on x      { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutQuint } }
        Behavior on y      { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutQuint } }
        Behavior on width  { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutQuint } }
        Behavior on height { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutQuint } }
        Behavior on radius { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: view.sys.animMs } }
    }

    // клик по пустому месту закрывает — как у обзора столов
    MouseArea {
        anchors.fill: parent
        onClicked: view.sys.closeWalls()
        onWheel: wheel => {
            var d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : -wheel.angleDelta.x;
            if (d === 0) return;
            // при смене направления копить заново, иначе прежний остаток
            // сначала уводит ленту в прежнюю сторону
            if ((d > 0) !== (view.wheelAcc > 0)) view.wheelAcc = 0;
            // ограничиваем запас: резкий рывок не должен ставить в очередь
            // десяток шагов, которые потом доигрываются сами
            view.wheelAcc = Math.max(-240, Math.min(240, view.wheelAcc + d));
            if (wheelCool.running || Math.abs(view.wheelAcc) < 120) return;
            view.wheelAcc += view.wheelAcc > 0 ? -120 : 120;
            view.move(view.wheelAcc > 0 ? -1 : (view.wheelAcc < 0 ? 1 : (d > 0 ? -1 : 1)));
            wheelCool.restart();
        }
    }

    // пауза между шагами: карточка успевает доехать до центра
    Timer { id: wheelCool; interval: 130 }

    // ------------------------------------------------------------- заголовок
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(view.height * 0.09)
        spacing: 2
        opacity: view.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: view.sys.animMs } }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: view.live ? view.sys.tr("Живые обои") : view.sys.tr("Обои")
            color: view.sys.colFg
            font {
                family: view.sys.fontFam
                pixelSize: view.sys.fontSize + 12; bold: true
            }
        }
        // Вкладки: картинки и видео. Карусель у них одна и та же — меняется
        // только источник строк и скрипт, который ставит фон.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            spacing: 8

            Repeater {
                model: [
                    { m: "still", t: view.sys.tr("Обои") },
                    { m: "live",  t: view.sys.tr("Живые обои") }
                ]
                Rectangle {
                    id: tabBtn
                    required property var modelData
                    readonly property bool picked: view.mode === tabBtn.modelData.m

                    Layout.preferredWidth: tabTxt.implicitWidth + 34
                    Layout.preferredHeight: 34
                    radius: 17
                    color: tabBtn.picked
                           ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g,
                                     view.sys.colOn.b, 0.24)
                           : (tabMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12)
                                                  : Qt.rgba(1, 1, 1, 0.06))
                    border.color: tabBtn.picked ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.10)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on border.color { ColorAnimation { duration: 160 } }

                    Text {
                        id: tabTxt
                        anchors.centerIn: parent
                        text: tabBtn.modelData.t
                        color: tabBtn.picked ? view.sys.colFg : view.sys.colMuted
                        font {
                            family: view.sys.fontFam
                            pixelSize: view.sys.fontSize - 2
                            bold: tabBtn.picked
                        }
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }
                    MouseArea {
                        id: tabMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.mode = tabBtn.modelData.m
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: walls.count
                  ? (view.target + 1) + " / " + walls.count
                  : (view.live ? view.sys.liveListReady : view.sys.wallListReady)
                    ? (view.live ? view.sys.tr("Папка живых обоев пуста")
                                 : view.sys.tr("Обоев не найдено"))
                    : view.sys.tr("Читаю…")
            color: view.sys.colMuted
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
        }
    }

    // -------------------------------------------------------------- карусель
    Item {
        id: reel
        anchors.fill: parent
        // Появляется вслед за подложкой, а при применении тает — на экране
        // остаётся только карточка, разворачивающаяся во весь экран.
        opacity: view.open ? 1 : 0
        scale: view.open ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: view.sys.animMs } }
        Behavior on scale {
            NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutQuint }
        }

        Repeater {
            model: walls

            Item {
                id: card
                required property int    index
                required property string wName
                required property string wThumb
                required property bool   wActive
                required property bool   wOwn
                required property string wPath

                // расстояние до центра в карточках: дробное, пока идёт ход
                readonly property real d: card.index - view.pos
                readonly property real ad: Math.abs(card.d)
                readonly property bool centered: card.ad < 0.5

                width: view.cardW
                height: view.cardH
                x: reel.width / 2 - width / 2 + card.d * view.step
                y: reel.height / 2 - height / 2
                // дальние карточки мельче и бледнее — получается глубина
                scale: Math.max(0.5, 1 - card.ad * 0.16)
                opacity: Math.max(0, 1 - card.ad * 0.34)
                visible: card.ad < 4.2
                z: Math.round(100 - card.ad * 10)

                // clip у прямоугольника режет по его РАМКЕ, а не по радиусу:
                // из скруглённой карточки торчали острые углы обоев. Поэтому
                // содержимое рисуется в невидимый слой и накрывается маской
                // со скруглением, а рамка ложится сверху.
                Item {
                    id: frame
                    anchors.fill: parent
                    readonly property int r: 22
                    z: 1

                    Item {
                        id: shot
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true

                        Rectangle { anchors.fill: parent; color: "#000000" }

                    // Параллакс: картинка шире рамки и едет в обратную сторону.
                    // Рамка ушла на step, картинка — только на часть его, и
                    // содержимое будто отстаёт от движения.
                    Image {
                        id: img
                        width: frame.width * 1.28
                        height: frame.height
                        x: -(frame.width * 0.14) + card.d * (view.step * 0.22)
                        // Грузим только то, что видно рядом с центром: иначе Qt
                        // берётся декодировать все три сотни разом, и открытие
                        // тянется секунды.
                        source: (card.ad < 5 && card.wThumb.indexOf("/") === 0)
                                ? "file://" + card.wThumb : ""
                        fillMode: Image.PreserveAspectCrop
                        // Пока миниатюры нет, сюда приходит исходник на 4K и
                        // больше. Без sourceSize Qt держал бы в памяти сотни
                        // полноразмерных кадров — по одному на карточку.
                        sourceSize.width: Math.round(view.cardW * 1.4)
                        asynchronous: true
                        cache: true
                        smooth: true
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                        }
                    }

                    // пока картинка грузится — мягкая пульсация вместо пустоты
                    Rectangle {
                        id: pulse
                        anchors.fill: parent
                        visible: img.status === Image.Loading
                        color: Qt.rgba(1, 1, 1, 0.06)
                        // именно по id: внутри анимации parent — null
                        SequentialAnimation on opacity {
                            running: pulse.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 620 }
                            NumberAnimation { to: 1.0;  duration: 620 }
                        }
                    }

                    // затемнение у боковых: центр должен читаться главным
                    Rectangle {
                        anchors.fill: parent
                        color: "#000000"
                        opacity: Math.min(0.55, card.ad * 0.3)
                    }
                    }

                    // маска: белое там, где картинку видно
                    Item {
                        id: cardMask
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        Rectangle {
                            anchors.fill: parent
                            radius: frame.r
                            color: "#ffffff"
                        }
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: shot
                        maskEnabled: true
                        maskSource: cardMask
                    }

                    // рамка поверх маски: под ней она обрезалась бы вместе с
                    // картинкой и выглядела тоньше на скруглениях
                    Rectangle {
                        anchors.fill: parent
                        radius: frame.r
                        color: "transparent"
                        border.color: card.wActive ? view.sys.colOn
                                    : card.centered ? Qt.rgba(1, 1, 1, 0.55)
                                                    : Qt.rgba(1, 1, 1, 0.10)
                        border.width: card.centered || card.wActive ? 2 : 1
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                    }

                    // подпись — только у центральной, чтобы не рябило.
                    // Живёт вне маски: внутри неё кнопки не получали бы клики.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 62
                        radius: frame.r
                        opacity: card.centered ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.72) }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 14
                            anchors.bottomMargin: 4
                            spacing: 10

                            Text {
                                Layout.fillWidth: true
                                text: view.pretty(card.wName)
                                color: view.sys.colFg
                                elide: Text.ElideRight
                                font {
                                    family: view.sys.fontFam
                                    pixelSize: view.sys.fontSize + 1; bold: true
                                }
                            }

                            // отметка «стоят сейчас»
                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                radius: 13
                                visible: card.wActive && view.applying.length === 0
                                color: view.sys.colOn
                                Text {
                                    anchors.centerIn: parent
                                    text: String.fromCodePoint(0xF012C)
                                    color: "#ffffff"
                                    font { family: view.sys.fontFam; pixelSize: 13 }
                                }
                            }

                            // корзина — только у своих обоев
                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                radius: 13
                                visible: card.wOwn && !card.wActive
                                color: delMa.containsMouse ? view.sys.colCrit
                                                           : Qt.rgba(1, 1, 1, 0.12)
                                Behavior on color { ColorAnimation { duration: 140 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: String.fromCodePoint(0xF01B4)
                                    color: delMa.containsMouse ? "#ffffff" : view.sys.colMuted
                                    font { family: view.sys.fontFam; pixelSize: 13 }
                                }
                                MouseArea {
                                    id: delMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: view.removeWall(card.wName)
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    // боковую сначала ставим в центр, и только потом применяем
                    onClicked: {
                        if (card.centered) view.activate();
                        else { view.userScrolled = true; view.target = card.index; }
                    }
                }
            }
        }
    }

    // Выбранные обои разлетаются во весь экран: пока скрипт работает, карточка
    // растёт до кромок и тает — под ней уже новый фон.
    Rectangle {
        id: burst
        visible: view.flying.length > 0
        anchors.centerIn: parent
        width: view.flying.length ? view.width : view.cardW
        height: view.flying.length ? view.height : view.cardH
        radius: view.flying.length ? 0 : 22
        clip: true
        // не чёрный: пока крупная картинка декодируется, чёрная заливка
        // мелькала на весь экран
        color: "transparent"
        opacity: view.applying.length ? 1 : 0
        z: 200
        Behavior on width   { NumberAnimation { duration: 520; easing.type: Easing.OutQuint } }
        Behavior on height  { NumberAnimation { duration: 520; easing.type: Easing.OutQuint } }
        Behavior on radius  { NumberAnimation { duration: 520; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

        // снизу — готовая миниатюра, сверху та же картинка в полном размере;
        // вторая проявляется, когда декодируется, и подмены не видно
        Image {
            id: burstThumb
            anchors.fill: parent
            source: view.flyingThumb.length ? "file://" + view.flyingThumb : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: true
        }
        Image {
            anchors.fill: parent
            source: view.flying.length ? "file://" + view.flying : ""
            fillMode: Image.PreserveAspectCrop
            // без ограничения Qt отказывается декодировать обои на десятки
            // мегапикселей: у него лимит 256 МБ на картинку
            sourceSize.width: view.width
            asynchronous: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }
        }
    }

    // --------------------------------------------------------------- подсказки
    RowLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(view.height * 0.08)
        spacing: 22
        opacity: view.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: view.sys.animMs } }

        Repeater {
            model: [
                { k: "← →",   t: view.sys.tr("выбрать") },
                { k: "Enter", t: view.sys.tr("поставить") },
                { k: "Esc",   t: view.sys.tr("закрыть") }
            ]
            RowLayout {
                required property var modelData
                spacing: 7
                Rectangle {
                    Layout.preferredWidth: hintKey.implicitWidth + 16
                    Layout.preferredHeight: 26
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.10)
                    Text {
                        id: hintKey
                        anchors.centerIn: parent
                        text: modelData.k
                        color: view.sys.colFg
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                    }
                }
                Text {
                    text: modelData.t
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
            }
        }

        // Папка живых обоев: складывать видео надо именно туда, поэтому её
        // открывает проводник — искать путь руками не нужно.
        Rectangle {
            visible: view.live
            // Ширина по содержимому, но не уже прежней: она была подобрана на
            // глаз под русскую надпись, и на другом языке текст вылезал за
            // края плашки.
            Layout.preferredWidth: Math.max(196, liveRow.implicitWidth + 24)
            Layout.preferredHeight: 38
            radius: 13
            color: folderMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
            border.color: folderMa.containsMouse ? view.sys.colOn : view.sys.colLine
            border.width: 1
            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on border.color { ColorAnimation { duration: 160 } }

            RowLayout {
                id: liveRow
                anchors.centerIn: parent
                spacing: 8
                Text {
                    text: String.fromCodePoint(0xF024B)
                    color: folderMa.containsMouse ? view.sys.colOn : view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 16 }
                }
                Text {
                    text: view.sys.tr("Папка живых обоев")
                    color: folderMa.containsMouse ? view.sys.colFg : view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
            }
            MouseArea {
                id: folderMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: view.sys.openLiveFolder()
            }
        }

        // свои обои — через проводник, как и раньше
        Rectangle {
            visible: !view.live
            // Ширина по содержимому, но не уже прежней: она была подобрана на
            // глаз под русскую надпись, и на другом языке текст вылезал за
            // края плашки.
            Layout.preferredWidth: Math.max(156, ownRow.implicitWidth + 24)
            Layout.preferredHeight: 38
            radius: 13
            color: addMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
            border.color: addMa.containsMouse ? view.sys.colOn : view.sys.colLine
            border.width: 1
            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on border.color { ColorAnimation { duration: 160 } }

            RowLayout {
                id: ownRow
                anchors.centerIn: parent
                spacing: 8
                Text {
                    text: String.fromCodePoint(0xF0415)
                    color: addMa.containsMouse ? view.sys.colOn : view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 16 }
                }
                Text {
                    text: view.sys.tr("Свои обои")
                    color: addMa.containsMouse ? view.sys.colFg : view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
            }
            MouseArea {
                id: addMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: view.sys.startWallpaperPick()
            }
        }
    }

    // ------------------------------------------------------ удаление своих
    Process { id: pDel }
    function removeWall(name) {
        pDel.command = ["sh", "-c",
            view.sys.scriptDir + "/themes.sh del \"$1\"", "_", name];
        pDel.running = true;
        delTimer.restart();
    }
    Timer {
        id: delTimer
        interval: 250
        onTriggered: view.sys.refreshWalls()
    }

    // Свои обои приходят из проводника уже путём — имя спрашивать незачем,
    // оно берётся из имени файла.
    Process {
        id: pAdd
        onRunningChanged: if (!running) { view.sys.wallpaperPick = ""; view.sys.refreshWalls(); }
    }
    onVisibleChanged: if (visible) view.takePick()
    function takePick() {
        if (view.sys.wallpaperPick.length === 0) return;
        pAdd.command = ["sh", "-c",
            view.sys.scriptDir + "/themes.sh add \"$1\"", "_", view.sys.wallpaperPick];
        pAdd.running = true;
    }
    Connections {
        target: view.sys
        function onWallpaperPickChanged() { view.takePick(); }
    }
}
