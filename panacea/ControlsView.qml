import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Bluetooth

// Раскрытая панель без музыки: Wi-Fi и Bluetooth.
//
// Три страницы внутри одной панели (sys.page):
//   main — две плитки-переключателя
//   wifi — список сетей + ввод пароля
//   bt   — список устройств
Item {
    id: view
    property var sys

    // Макет для вкладки настроек: та же панель, только неживая. Показывает
    // всегда главную страницу и слушается не сохранённой раскладки, а той,
    // что человек прямо сейчас двигает мышью.
    property bool preview: false
    property var ccOrderOverride: null

    // ------------------------------------------------- порядок блоков панели
    // Пустая настройка — заводской порядок. Неизвестные имена (остались от
    // прежней версии) отбрасываются, забытые дописываются в конец: раскладка
    // переживает и обновление оболочки, и правку файла руками.
    readonly property var ccDefault: ["clock", "toggles", "sliders", "media", "power", "quick", "tray"]
    readonly property var ccOrder: {
        if (view.ccOrderOverride) return view.ccOrderOverride;
        var saved = String(view.sys.cfg.ccLayout || "").split(",").filter(x => x.length);
        var out = saved.filter(id => view.ccDefault.indexOf(id) >= 0);
        view.ccDefault.forEach(id => { if (out.indexOf(id) < 0) out.push(id); });
        return out;
    }
    // прямоугольник блока в координатах панели — по нему макет ставит
    // накладку для перетаскивания
    function ccBlock(id) {
        for (var i = 0; i < mainPage.children.length; i++)
            if (mainPage.children[i].objectName === "cc-" + id) return mainPage.children[i];
        return null;
    }
    function ccRow(id) {
        var i = view.ccOrder.indexOf(id);
        return i < 0 ? view.ccDefault.indexOf(id) : i;
    }

    // «м:сс» для полосы продолжительности; часы появляются только если нужны
    function fmtTime(sec) {
        var t = Math.max(0, Math.floor(sec));
        var h = Math.floor(t / 3600);
        var m = Math.floor((t % 3600) / 60);
        var s = t % 60;
        var mm = h > 0 && m < 10 ? "0" + m : String(m);
        return (h > 0 ? h + ":" : "") + mm + ":" + (s < 10 ? "0" + s : String(s));
    }

    implicitHeight: stack.implicitHeight

    focus: true
    Component.onCompleted: forceActiveFocus()

    // Возврат на плитки. Вынесено в функцию, потому что Escape не всегда
    // доходит сюда: фокус может сидеть в поле пароля Wi-Fi или в списке, и
    // тогда событие всплывает мимо — до Loader'а в shell.qml. Он зовёт
    // goBack() сам, и подстраница закрывается вместо всей панели.
    function goBack() {
        // с меню сети возвращаемся к списку, а не на плитки: человек пришёл
        // сюда из списка и туда же ждёт назад
        if (view.sys.page === "netmenu") {
            view.sys.page = "wifi";
            return true;
        }
        if (view.sys.page === "wifi" || view.sys.page === "bt"
            || view.sys.page === "battery") {
            view.sys.page = "main";
            return true;
        }
        if (view.sys.page === "traymenu") {
            view.sys.page = "main";
            view.sys.trayMenuItem = null;
            return true;
        }
        return false;
    }

    Keys.onEscapePressed: {
        // с подстраниц Esc возвращает назад, с главной — закрывает панель
        if (!view.goBack()) view.sys.collapse();
    }

    // ------------------------------------------------------- общие компоненты

    // Сегмент выбора режима питания: иконка + подпись, активный подсвечен
    component PowerSeg: Rectangle {
        property string icon: ""
        property string label: ""
        property string profile: ""
        property color accent: view.sys.colOn
        readonly property bool active: view.sys.powerProfile === profile

        Layout.fillWidth: true
        Layout.preferredHeight: 54
        radius: 14
        color: active ? Qt.rgba(accent.r, accent.g, accent.b, 0.18)
                      : (segMa.containsMouse ? Qt.rgba(1, 1, 1, 0.09)
                                             : Qt.rgba(1, 1, 1, 0.05))
        border.color: active ? Qt.rgba(accent.r, accent.g, accent.b, 0.40)
                             : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        scale: segMa.pressed ? 0.95 : 1.0
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.icon
                color: parent.parent.active ? parent.parent.accent : "#ffffff"
                font { family: view.sys.fontFam; pixelSize: 17 }
                Behavior on color { ColorAnimation { duration: 180 } }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.label
                color: parent.parent.active ? view.sys.colFg : view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: 11; bold: parent.parent.active }
                Behavior on color { ColorAnimation { duration: 180 } }
            }
        }

        MouseArea {
            id: segMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.sys.setPowerProfile(parent.profile)
        }
    }

    // Плитка: слева иконка (переключает), справа название (открывает список)
    component Tile: Rectangle {
        property string icon: ""
        property string label: ""
        property string sub: ""
        property bool on: false
        property color accent: view.sys.colOn
        signal iconClicked()
        signal bodyClicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 62
        radius: 16
        color: on ? Qt.rgba(accent.r, accent.g, accent.b, 0.16) : Qt.rgba(1, 1, 1, 0.05)
        border.color: on ? Qt.rgba(accent.r, accent.g, accent.b, 0.35) : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 12
            spacing: 11

            // круглая кнопка-иконка — включить/выключить
            Rectangle {
                id: iconBtn
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 20
                color: parent.parent.on ? parent.parent.accent : Qt.rgba(1, 1, 1, 0.10)
                Behavior on color { ColorAnimation { duration: 180 } }
                scale: iconMa.pressed ? 0.9 : (iconMa.containsMouse ? 1.06 : 1.0)
                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

                Text {
                    anchors.centerIn: parent
                    text: iconBtn.parent.parent.icon
                    color: "#ffffff"
                    font { family: view.sys.fontFam; pixelSize: 17 }
                }
                MouseArea {
                    id: iconMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: iconBtn.parent.parent.iconClicked()
                }
            }

            // подпись — открывает список
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: iconBtn.parent.parent.label
                    color: view.sys.colFg
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    text: iconBtn.parent.parent.sub
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 11 }
                }
            }

            Text {
                text: ""
                color: bodyMa.containsMouse ? view.sys.colFg : view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: 13 }
                Behavior on color { ColorAnimation { duration: 130 } }
            }
        }

        MouseArea {
            id: bodyMa
            anchors.fill: parent
            anchors.leftMargin: 58     // не перекрываем круглую кнопку
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.bodyClicked()
        }
    }

    // Кнопка-иконка нижнего ряда: замок, уведомления, настройки.
    // Тултип — та же чёрная капсула, что всплывает над значками трея.
    component IconBtn: Rectangle {
        property string glyph: ""
        property string tip: ""
        property color glyphColor: view.sys.colMuted
        property color activeColor: view.sys.colFg
        property bool active: false
        property int badge: 0
        signal act()

        implicitWidth: 44
        implicitHeight: 44
        radius: 13
        z: ibMa.containsMouse ? 10 : 0
        color: ibMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
        border.color: active ? Qt.rgba(view.sys.colOk.r, view.sys.colOk.g, view.sys.colOk.b, 0.5) : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on border.color { ColorAnimation { duration: 160 } }

        scale: ibMa.pressed ? 0.9 : (ibMa.containsMouse ? 1.06 : 1.0)
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

        Glyph {
            anchors.fill: parent
            glyph: parent.glyph
            color: parent.active ? parent.activeColor
                 : ibMa.containsMouse ? view.sys.colFg : parent.glyphColor
            fontFam: view.sys.fontFam
            size: view.sys.iconSize - 2
        }

        // счётчик непрочитанных — только у колокольчика
        Rectangle {
            width: 15; height: 15; radius: 8
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 2
            visible: parent.badge > 0
            color: view.sys.colOn
            Text {
                anchors.centerIn: parent
                text: parent.parent.badge > 9 ? "9+" : parent.parent.badge
                // кружок налит акцентом: на светлом акценте белая цифра
                // пропадает целиком
                color: view.sys.fgOn(view.sys.colOn)
                font { family: view.sys.fontFam; pixelSize: 9; bold: true }
            }
        }

        MouseArea {
            id: ibMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.act()
        }

        Rectangle {
            id: ibTip
            visible: opacity > 0.01
            opacity: (ibMa.containsMouse && parent.tip.length) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }

            width: ibTipText.implicitWidth + 20
            height: 26
            radius: 13
            x: (parent.width - width) / 2
            y: -height - 8
            color: Qt.rgba(0.04, 0.04, 0.05, 0.96)
            border.color: view.sys.colLine
            border.width: 1

            scale: ibMa.containsMouse ? 1 : 0.92
            transformOrigin: Item.Bottom
            Behavior on scale {
                NumberAnimation { duration: 160; easing.type: Easing.OutBack }
            }

            Text {
                id: ibTipText
                anchors.centerIn: parent
                text: ibTip.parent.tip
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 11 }
            }
        }
    }

    // Волна «идёт зарядка»: две несинхронные синусоиды, налитые до уровня
    // заряда и медленно ползущие вбок. Скругление рисуем прямо в канве и
    // используем как маску — обычный clip у Item только прямоугольный.
    component ChargeWave: Canvas {
        property color tint: view.sys.colOk
        property real level: 0.5        // доля высоты, до которой налито
        property real radius: 14
        property bool running: false
        property real phase: 0

        opacity: running ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }

        onPhaseChanged: requestPaint()
        onLevelChanged: requestPaint()
        // Без этого волна остаётся того цвета, каким её нарисовали в первый
        // раз: канва сама себя не перерисовывает, а цвет приходит от темы и
        // меняется на ходу — после переключения на Nothing заливка оставалась
        // зелёной от прежней темы.
        onTintChanged: requestPaint()

        Timer {
            interval: 45
            running: parent.running && parent.visible
            repeat: true
            onTriggered: parent.phase += 0.16
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (width <= 0 || height <= 0) return;

            // маска — скруглённый прямоугольник плитки
            var r = Math.min(radius, Math.min(width, height) / 2);
            ctx.beginPath();
            ctx.moveTo(r, 0);
            ctx.arcTo(width, 0, width, height, r);
            ctx.arcTo(width, height, 0, height, r);
            ctx.arcTo(0, height, 0, 0, r);
            ctx.arcTo(0, 0, width, 0, r);
            ctx.closePath();
            ctx.clip();

            // Уровень держим в стороне от краёв: у самого верха волна
            // срезается маской и выглядит как ровная полоса.
            var base = height * (1 - Math.max(0.12, Math.min(0.92, level)));
            var amp = 3.2;

            for (var w = 0; w < 2; w++) {
                var off = w === 0 ? 0 : Math.PI * 0.7;
                var k = w === 0 ? 0.055 : 0.041;
                ctx.beginPath();
                ctx.moveTo(0, height);
                for (var x = 0; x <= width; x += 3) {
                    var y = base + amp * Math.sin(k * x + phase + off)
                                 + amp * 0.5 * Math.sin(k * 1.9 * x - phase * 0.7);
                    if (x === 0) ctx.lineTo(0, y); else ctx.lineTo(x, y);
                }
                ctx.lineTo(width, height);
                ctx.closePath();
                ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, w === 0 ? 0.16 : 0.11);
                ctx.fill();
            }
        }
    }

    // Компактная плитка для верхней строки: Wi-Fi и Bluetooth стоят рядом,
    // а не двумя полосами друг под другом. Иконка меньше, подпись в две
    // строки, шеврон убран — на треть ширины он только съедал место.
    component MiniTile: Rectangle {
        id: tile
        property string icon: ""
        // Значок фигурой вместо знака шрифта. Нужен там, где подходящего
        // глифа просто нет: проводная сеть в Nerd Font рисуется деревом с
        // перекладиной шире самих квадратов, и на этих размерах она читается
        // полосой поперёк значка. Пусто — берётся icon, как раньше.
        property Component iconItem: null
        property string label: ""
        property string sub: ""
        property bool on: false
        property color accent: view.sys.colOn
        // плитка батареи наливается волной, пока идёт зарядка
        property bool wave: false
        property real waveLevel: 0.5
        signal iconClicked()
        signal bodyClicked()

        // На теме Nothing включённая плитка наливается акцентом целиком, а
        // не подсвечивается им на одну шестую. Там нет цвета, которым можно
        // «намекнуть»: разница между включённым и выключенным держится
        // только на яркости, и полупрозрачная подсветка белым по чёрному
        // читается как «плитка чуть светлее», а не как «работает».
        //
        // Кружок значка при этом становится чёрным — выворачивается вместе
        // с плиткой, иначе белое на белом сливается в пятно.
        // Залитой плитка не становится, пока по ней идёт волна: волна и есть
        // указание, что заряжается, и на белой заливке она пропадала —
        // рисуется она полупрозрачным поверх фона, а поверх белого белым не
        // видно ничего. Двух указаний на одно и то же и не нужно.
        readonly property bool solid: view.sys.themeNothing && tile.on && !tile.wave
        // цвет подписей: на залитой плитке они тёмные
        readonly property color ink: tile.solid ? view.sys.fgOn(tile.accent)
                                                : view.sys.colFg

        // implicitWidth обязателен: содержимое прижато якорями, поэтому своей
        // ширины у плитки нет, и RowLayout отдавал всю строку соседу — три
        // карточки схлопывались друг на друга в точке 0,0.
        implicitWidth: 140
        implicitHeight: 56
        radius: 14
        color: solid ? accent
             : on ? Qt.rgba(accent.r, accent.g, accent.b, 0.16)
                  : Qt.rgba(1, 1, 1, 0.05)
        border.color: solid ? accent
                    : on ? Qt.rgba(accent.r, accent.g, accent.b, 0.35)
                         : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        // под содержимым: волна не должна перекрывать подписи
        ChargeWave {
            anchors.fill: parent
            radius: parent.radius
            tint: parent.accent
            level: parent.waveLevel
            running: parent.wave
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 10
            spacing: 8

            Rectangle {
                id: miniIcon
                // крупнее прежних 30: в одном ряду с замком и шестернёй
                // мелкие кружки выглядели вдавленными
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 19
                color: tile.solid ? view.sys.colBg
                     : tile.on ? tile.accent
                               : Qt.rgba(1, 1, 1, 0.10)
                Behavior on color { ColorAnimation { duration: 180 } }
                scale: miniIconMa.pressed ? 0.9 : (miniIconMa.containsMouse ? 1.07 : 1.0)
                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

                // Значок лежит прямо на кружке, и цвет берётся от него: на
                // акцентном кружке белый по белому не виден вовсе, а на
                // вывернутом чёрном — наоборот, только белый и виден.
                readonly property color ink: tile.solid ? "#ffffff"
                                           : tile.on ? view.sys.fgOn(tile.accent)
                                                     : "#ffffff"

                Text {
                    anchors.centerIn: parent
                    visible: tile.iconItem === null
                    text: tile.icon
                    color: miniIcon.ink
                    font { family: view.sys.fontFam; pixelSize: 17 }
                }

                Loader {
                    id: iconLoader
                    anchors.centerIn: parent
                    active: tile.iconItem !== null
                    sourceComponent: tile.iconItem
                }

                // Цвет фигуре — тот же, что достался бы знаку. Отдельным
                // Binding, а не присваиванием в onLoaded: цвет меняется,
                // когда плитку включают, и разовой записи при загрузке не
                // хватило бы.
                Binding {
                    target: iconLoader.item
                    property: "color"
                    value: miniIcon.ink
                    when: iconLoader.item !== null
                }
                MouseArea {
                    id: miniIconMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: miniIcon.parent.parent.iconClicked()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: tile.label
                    color: tile.ink
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: tile.sub
                    // На залитой плитке приглушаем не общим colMuted — тот
                    // построен от цвета текста темы, то есть от белого, и на
                    // белом фоне выцветает в ничто.
                    color: tile.solid
                           ? Qt.rgba(tile.ink.r, tile.ink.g, tile.ink.b, 0.6)
                           : view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 10 }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.leftMargin: 44     // не перекрываем круглую кнопку
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.bodyClicked()
        }
    }

    // Мелкая плашка с цифрой на странице батареи
    component BattStat: Rectangle {
        property string label: ""
        property string value: ""

        implicitWidth: 90
        implicitHeight: 44
        Layout.fillWidth: true
        radius: 12
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: view.sys.colLine
        border.width: 1

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 0
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.label
                color: view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: 10 }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.value
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 12; bold: true }
            }
        }
    }

    // Круглая кнопка управления плеером в карточке трека.
    component MediaBtn: Rectangle {
        property string icon: ""
        property bool primary: false
        property bool enabledAction: true
        signal act()

        implicitWidth: primary ? 42 : 34
        implicitHeight: primary ? 42 : 34
        radius: width / 2
        color: primary ? view.sys.colFg
              : (mbMa.containsMouse ? view.sys.colHover : Qt.rgba(1, 1, 1, 0.08))
        opacity: enabledAction ? 1 : 0.35
        Behavior on color { ColorAnimation { duration: 140 } }
        scale: mbMa.pressed ? 0.9 : (mbMa.containsMouse ? 1.08 : 1.0)
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

        Text {
            anchors.centerIn: parent
            text: parent.icon
            color: parent.primary ? view.sys.colBg : view.sys.colFg
            font { family: view.sys.fontFam; pixelSize: parent.primary ? 17 : 14 }
        }
        MouseArea {
            id: mbMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: parent.enabledAction
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.act()
        }
    }

    // Карточка звука той же высоты: название устройства сверху, под ним
    // ползунок прямо в плитке — громкость правится не уходя на страницу.
    // Дорожка-ползунок: заполнение и есть ручка, как в iOS — отдельный кружок
    // на такой высоте некуда было бы поставить. Одна на громкость и яркость:
    // они стоят рядом в одной строке, и любое расхождение в поведении между
    // соседними ползунками читается как поломка одного из них.
    component Track: Item {
        id: trk

        property real pos: 0                  // 0..1 — что показывать
        property string icon: ""              // значок слева, поверх заливки
        property string valueText: ""         // цифра справа
        property real wheelStep: 0.05
        property bool dim: false              // выключено (без звука)

        signal setFrac(real frac)
        signal iconClicked()

        implicitHeight: 22

        readonly property real padL: trk.icon.length ? 22 : 0
        function fracAt(x) {
            return Math.max(0, Math.min(1, (x + trk.padL) / Math.max(1, trk.width)));
        }

        // Заливка не анимируется в двух случаях: пока её тянут — она обязана
        // стоять точно под курсором, иначе догон читается как задержка ввода;
        // и в первые мгновения после создания — значение приходит уже после
        // него, и полоска каждый раз разъезжалась бы от нуля до своего места
        // на глазах у человека, открывшего панель.
        property bool live: false
        Component.onCompleted: liveTimer.start()
        Timer { id: liveTimer; interval: 260; onTriggered: trk.live = true }

        // Своя отметка на время серии прокруток колесом, см. onWheel ниже.
        property real wheelFrom: -1
        Timer { id: wheelIdle; interval: 260; onTriggered: trk.wheelFrom = -1 }

        // Пока человек крутит — показываем ровно то, что он задал, не
        // дожидаясь подтверждения. Громкость подтверждает Pipewire сигналом,
        // яркость монитор по I2C через десятки миллисекунд; если рисовать
        // только подтверждённое, при быстрой прокрутке полоска и число
        // прыгают назад к предыдущему значению. Отпустил и всё устоялось —
        // возвращаемся к настоящему.
        property real held: -1
        readonly property real shown: trk.held >= 0 ? trk.held : trk.pos
        Timer { id: heldIdle; interval: 400; onTriggered: trk.held = -1 }
        function put(frac) {
            trk.held = Math.max(0, Math.min(1, frac));
            heldIdle.restart();
            trk.setFrac(trk.held);
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.12)
            clip: true

            Rectangle {
                width: Math.max(parent.height, parent.width * trk.shown)
                height: parent.height
                radius: height / 2
                color: view.sys.colFg
                opacity: trk.dim ? 0.45 : 1
                Behavior on width {
                    enabled: trk.live && !trkMa.pressed
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
        }

        Text {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            visible: trk.icon.length > 0
            text: trk.icon
            color: view.sys.colBg
            font { family: view.sys.fontFam; pixelSize: 15 }
        }

        Text {
            id: trkVal
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 8
            text: trk.valueText
            // Заливка и есть ручка, поэтому цифра оказывается то на светлом,
            // то на тёмном: перекрашиваем на границе, иначе она пропадает.
            color: (trk.width * trk.shown) > (trk.width - trkVal.width - 12)
                   ? view.sys.colBg : view.sys.colFg
            font { family: view.sys.fontFam; pixelSize: 11; bold: true }
        }

        MouseArea {
            id: trkMa
            anchors.fill: parent
            // клик по самому значку — не тянуть, а нажать на него
            anchors.leftMargin: trk.padL
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => trk.put(trk.fracAt(mouse.x))
            onPositionChanged: mouse => { if (pressed) trk.put(trk.fracAt(mouse.x)); }
            // Колесо поверх дорожки. На клавиатуре без мультимедийных клавиш
            // это единственный способ подправить значение, не целясь мышью в
            // тонкую полоску, — и привычка из любой другой оболочки.
            //
            // Считаем от собственной отметки, а не от pos: и громкость, и
            // яркость подтверждаются не сразу — Pipewire отвечает сигналом,
            // монитор по I2C и вовсе через десятки миллисекунд. При быстрой
            // прокрутке следующее деление успевало прочитать ещё не
            // обновившееся значение, и число прыгало туда-сюда вместо того,
            // чтобы расти. Отметка живёт до паузы в прокрутке, дальше снова
            // берём настоящее значение.
            onWheel: wheel => {
                var d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                if (d === 0) return;
                var base = trk.wheelFrom >= 0 ? trk.wheelFrom : trk.shown;
                // Ровно по делениям: иначе от дробного начала вся дальнейшая
                // прокрутка идёт мимо круглых чисел.
                var steps = Math.round(base / trk.wheelStep) + (d > 0 ? 1 : -1);
                var next = Math.max(0, Math.min(1, steps * trk.wheelStep));
                trk.wheelFrom = next;
                wheelIdle.restart();
                trk.put(next);
            }
        }

        MouseArea {
            width: 22
            height: parent.height
            visible: trk.icon.length > 0
            cursorShape: Qt.PointingHandCursor
            onClicked: trk.iconClicked()
        }
    }

    component VolCard: Rectangle {
        implicitWidth: 190
        implicitHeight: 56
        radius: 14
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: view.sys.colLine
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            anchors.topMargin: 7
            // Снизу больше, чем сверху: дорожка тоньше заголовка и при равных
            // отступах садилась на кромку карточки, читаясь как её край.
            anchors.bottomMargin: 11
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: view.sys.tr("Звук")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.togglePage("audio")
                    }
                }
                // Имя устройства занимает остаток строки и обрезается по
                // нему. Постоянные 130 пикселей подходили, пока имя короткое:
                // «OnePlus Buds 3» в них не помещался и уезжал за край
                // карточки — обрезать нечего, если ширина задана числом,
                // которое больше доступного места.
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: view.sys.sinkName.length ? view.sys.sinkName
                                                   : view.sys.tr("Нет устройств")
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 10 }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.togglePage("audio")
                    }
                }
            }

            // Уровень цифрой: полоска показывает громкость лишь примерно, а
            // точное число до сих пор было только в накладке от клавиш
            // громкости — на клавиатуре без мультимедийных кнопок вызвать её
            // нечем, и точного значения негде было взять.
            Track {
                id: vol
                Layout.fillWidth: true
                Layout.preferredHeight: 22

                readonly property var a: view.sys.sinkAudio

                pos: vol.a ? vol.a.volume : 0
                dim: vol.a ? vol.a.muted : true
                icon: !vol.a ? String.fromCodePoint(0xF075F)
                    : vol.a.muted ? String.fromCodePoint(0xF075F)
                    : vol.a.volume < 0.34 ? String.fromCodePoint(0xF057F)
                    : vol.a.volume < 0.67 ? String.fromCodePoint(0xF0580)
                                          : String.fromCodePoint(0xF057E)
                valueText: !vol.a ? "—"
                    : vol.a.muted ? view.sys.tr("Без звука")
                                  : Math.round(vol.shown * 100) + "%"
                // шаг 5%, как у мультимедийных клавиш
                onSetFrac: f => { if (vol.a) vol.a.volume = Math.round(f * 20) / 20; }
                onIconClicked: if (vol.a) vol.a.muted = !vol.a.muted
            }
        }
    }

    // Яркость — карточка ровно того же сложения, что и звук: они стоят рядом
    // в одной строке. Значение держим своё, а не спрашиваем монитор на каждый
    // кадр: DDC отвечает десятки миллисекунд, и ползунок, ждущий шину, дёргался
    // бы под рукой.
    component BrightCard: Rectangle {
        id: brCard
        property string bid: ""
        property int    bpct: 0
        property string bname: ""

        implicitWidth: 190
        implicitHeight: 56
        radius: 14
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: view.sys.colLine
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            anchors.topMargin: 7
            anchors.bottomMargin: 8
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: view.sys.tr("Яркость")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                }
                Item { Layout.fillWidth: true }
                Text {
                    Layout.maximumWidth: 130
                    // Имя экрана нужно, только когда их несколько: на одном
                    // мониторе подписывать нечего.
                    visible: brCard.bname.length > 0
                    text: brCard.bname
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 10 }
                }
            }

            Track {
                id: brTrk
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                pos: Math.max(0, Math.min(1, brCard.bpct / 100))
                icon: String.fromCodePoint(0xF00DD)   // солнце
                valueText: Math.round(brTrk.shown * 100) + "%"
                // шаг 5%, как у клавиш яркости
                onSetFrac: f => view.sys.brightSet(brCard.bid, Math.round(f * 20) * 5)
            }
        }
    }

    // Шапка страницы-списка: назад + заголовок + обновить
    component Header: RowLayout {
        property string title: ""
        property bool busy: false
        signal back()
        signal refresh()

        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            Layout.preferredWidth: 28; Layout.preferredHeight: 28
            radius: 14
            color: backMa.containsMouse ? view.sys.colHover : "transparent"
            Behavior on color { ColorAnimation { duration: 130 } }
            Text {
                anchors.centerIn: parent; text: ""
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 13 }
            }
            MouseArea {
                id: backMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.parent.back()
            }
        }
        Text {
            Layout.fillWidth: true
            text: parent.title
            color: view.sys.colFg
            font { family: view.sys.fontFam; pixelSize: 13; bold: true }
        }
        Rectangle {
            Layout.preferredWidth: 28; Layout.preferredHeight: 28
            radius: 14
            color: refMa.containsMouse ? view.sys.colHover : "transparent"
            Behavior on color { ColorAnimation { duration: 130 } }
            Text {
                id: refIcon
                anchors.centerIn: parent; text: "󰑐"
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 13 }
                RotationAnimator on rotation {
                    running: refIcon.parent.parent.busy
                    loops: Animation.Infinite
                    from: 0; to: 360; duration: 900
                }
            }
            MouseArea {
                id: refMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.parent.refresh()
            }
        }
    }

    // Строка списка
    component Row1: Rectangle {
        property string icon: ""
        property string title: ""
        property string sub: ""
        property bool highlight: false
        signal activated()
        // Правая кнопка: у сетей за ней прячется отключение и «забыть».
        // Строка сама ничего о них не знает — только сообщает о нажатии.
        signal menuRequested(real mx, real my)

        Layout.fillWidth: true
        Layout.preferredHeight: 42
        radius: 12
        color: rowMa.containsMouse ? view.sys.colHover
             : (highlight ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
        Behavior on color { ColorAnimation { duration: 130 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            spacing: 10
            Text {
                text: rowMa.parent.icon
                color: rowMa.parent.highlight ? view.sys.colOn : view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 15 }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: rowMa.parent.title
                    color: view.sys.colFg
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 12; bold: rowMa.parent.highlight }
                }
                Text {
                    text: rowMa.parent.sub
                    visible: text.length > 0
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 10 }
                }
            }
            Text {
                visible: rowMa.parent.highlight
                text: "󰄬"
                color: view.sys.colOn
                font { family: view.sys.fontFam; pixelSize: 13 }
            }
        }
        MouseArea {
            id: rowMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    var p = mapToItem(wifiPage, mouse.x, mouse.y);
                    parent.menuRequested(p.x, p.y);
                } else {
                    parent.activated();
                }
            }
        }
    }

    // Фигура значка проводной сети. Одна на всю панель: Loader создаёт по
    // своей копии там, где она понадобилась.
    Component {
        id: lanShape
        LanGlyph { width: 13; height: 13 }
    }

    // Число: точками на Nothing, обычным шрифтом на остальных темах.
    //
    // Раскладка панели у тем общая, разное только начертание, — поэтому
    // выбор спрятан сюда, а не размазан по каждому месту с цифрой. Кегль
    // шрифта берётся с запасом от высоты точечной цифры: у той высота и есть
    // весь рост, а у буквы pixelSize считается по всей строке.
    component Num: Item {
        id: num
        property string value: ""
        property real size: 12
        property real gapRatio: 0.22
        property color color: view.sys.colFg

        implicitWidth:  view.sys.themeNothing ? nDots.implicitWidth  : nPlain.implicitWidth
        implicitHeight: view.sys.themeNothing ? nDots.implicitHeight : nPlain.implicitHeight

        DotText {
            id: nDots
            visible: view.sys.themeNothing
            value: num.value
            size: num.size
            gapRatio: num.gapRatio
            color: num.color
        }
        Text {
            id: nPlain
            visible: !view.sys.themeNothing
            text: num.value
            color: num.color
            font { family: view.sys.fontFam; pixelSize: Math.round(num.size * 1.35) }
        }
    }

    // ------------------------------------------------------------ запись
    // Плашка записи для темы Nothing: круглая кнопка, подпись и таймер.
    //
    // Обычная плитка показывала на этом месте частоту кадров, пока запись не
    // идёт. Число это из настроек, меняют его раз в жизни, а места оно
    // занимает столько же, сколько отсчёт. Здесь вместо него всегда стоят
    // часы записи: до начала на нуле, дальше идут.
    component RecordCard: Rectangle {
        id: recCard

        radius: 14
        color: recBodyMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.05)
        border.color: view.sys.recActive
                      ? Qt.rgba(view.sys.colCrit.r, view.sys.colCrit.g,
                                view.sys.colCrit.b, 0.45)
                      : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        // тело открывает страницу записи, кнопка — начинает и останавливает
        MouseArea {
            id: recBodyMa
            anchors.fill: parent
            anchors.leftMargin: 52
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.sys.togglePage("record")
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 12
            spacing: 11

            Rectangle {
                id: recBtn
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignVCenter
                radius: 17
                // Идёт запись — кнопка налита красным, значит «нажми, чтобы
                // прекратить». Стоит — обычный кружок с треугольником.
                color: view.sys.recActive ? view.sys.colCrit : Qt.rgba(1, 1, 1, 0.10)
                Behavior on color { ColorAnimation { duration: 180 } }
                scale: recBtnMa.pressed ? 0.9 : (recBtnMa.containsMouse ? 1.07 : 1.0)
                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(view.sys.recActive ? 0xF04DB : 0xF040A)
                    color: view.sys.recActive
                           ? view.sys.fgOn(view.sys.colCrit) : "#ffffff"
                    font { family: view.sys.fontFam; pixelSize: 15 }
                }

                MouseArea {
                    id: recBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.toggleRecord()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    text: view.sys.tr("Запись")
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font {
                        family: view.sys.fontFam; pixelSize: 9
                        capitalization: Font.AllUppercase; letterSpacing: 1.2
                    }
                }

                // Отсчёт точками — как остальные числа темы. Пока запись не
                // идёт, он приглушён: нули в полную яркость читались бы как
                // «идёт и стоит на нуле».
                Num {
                    Layout.alignment: Qt.AlignLeft
                    value: view.sys.recTimeText
                    size: view.sys.dotHSmall + 3
                    color: !view.sys.recActive ? view.sys.colMuted
                         : view.sys.recPaused ? view.sys.colWarn
                                              : view.sys.colFg
                }
            }
        }
    }

    // ------------------------------------------------- нагрузка машины
    // Три строки: процессор, память, видео. Проценты — полоской и числом
    // сразу: полоска показывает «много или мало» с одного взгляда, число
    // отвечает «насколько именно», и одно другого не заменяет.
    component LoadRow: RowLayout {
        id: lrow
        property string glyph: ""
        property string name: ""
        property int pct: -1
        property int temp: -1

        // Мерить нечем — строки нет совсем. Полоска в нуле читалась бы как
        // «простаивает», а это другое утверждение.
        visible: lrow.pct >= 0
        spacing: 8

        Glyph {
            Layout.preferredWidth: 15
            Layout.preferredHeight: 15
            glyph: lrow.glyph
            color: view.sys.colMuted
            fontFam: view.sys.fontFam
            size: 12
        }

        Text {
            Layout.preferredWidth: 30
            text: lrow.name
            color: view.sys.colMuted
            font { family: view.sys.fontFam; pixelSize: 9; letterSpacing: 0.6 }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 3
            Layout.alignment: Qt.AlignVCenter
            radius: 1.5
            color: Qt.rgba(1, 1, 1, 0.12)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, lrow.pct)) / 100
                height: parent.height
                radius: parent.radius
                color: view.sys.colFg
                Behavior on width {
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }
            }
        }

        // Ширину под число резервируем по «100%», иначе полоска слева
        // дёргалась бы на каждом переходе через десяток.
        //
        // Меряем настоящим невидимым числом, а не круглой цифрой на глаз:
        // ширина точечного знака зависит и от высоты, и от просветов, и от
        // того, сколько столбцов сетки у «%». Прежние 30 пикселей были
        // меньше нужного едва не вдвое — число вылезало на полоску.
        Item {
            Layout.preferredWidth: pctRuler.implicitWidth
            Layout.preferredHeight: pctRuler.implicitHeight

            Num {
                id: pctRuler
                visible: false
                value: "100%"
                size: view.sys.dotHTiny
            }

            Num {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                value: lrow.pct + "%"
                size: view.sys.dotHTiny
                color: view.sys.colFg
            }
        }

        // Датчик есть не у всех: у процессора он почти всегда, у видео —
        // как повезёт с драйвером.
        RowLayout {
            spacing: 3
            visible: lrow.temp >= 0

            Glyph {
                Layout.preferredWidth: 11
                Layout.preferredHeight: 11
                glyph: String.fromCodePoint(0xF0E01)
                color: lrow.temp >= 80 ? view.sys.colCrit : view.sys.colMuted
                fontFam: view.sys.fontFam
                size: 10
            }
            Num {
                Layout.alignment: Qt.AlignVCenter
                value: lrow.temp + "°"
                size: view.sys.dotHTiny
                color: lrow.temp >= 80 ? view.sys.colCrit : view.sys.colMuted
            }
        }
    }

    component LoadCard: Rectangle {
        radius: 14
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: view.sys.colLine
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 4

            LoadRow {
                Layout.fillWidth: true
                glyph: String.fromCodePoint(0xF0EE0); name: "CPU"
                pct: view.sys.loadCpu; temp: view.sys.loadTempCpu
            }
            LoadRow {
                Layout.fillWidth: true
                glyph: String.fromCodePoint(0xF035B); name: "RAM"
                pct: view.sys.loadMem
            }
            LoadRow {
                Layout.fillWidth: true
                glyph: String.fromCodePoint(0xF0379); name: "GPU"
                pct: view.sys.loadGpu; temp: view.sys.loadTempGpu
            }
        }
    }

    // ------------------------------------------------------------- страницы
    Item {
        id: stack
        width: parent.width
        implicitHeight: (view.preview || view.sys.page === "main") ? mainPage.implicitHeight
                      : view.sys.page === "wifi" ? wifiPage.implicitHeight
                      : view.sys.page === "netmenu" ? netMenuPage.implicitHeight
                      : view.sys.page === "traymenu" ? trayPage.implicitHeight
                      : view.sys.page === "battery" ? battPage.implicitHeight
                      : btPage.implicitHeight
        // Высоту анимирует сама капсула в shell.qml. Вторая анимация здесь
        // складывалась с ней: капсула догоняла уже анимируемое значение,
        // и панель расширялась заметно дольше, чем нужно.

        // ---------------------------------------------------------- главная
        // Сетка в одну колонку, а не столбец: только она умеет явный номер
        // строки у каждого ребёнка. Порядок блоков задаётся во вкладке
        // Control Center и приходит сюда строкой из настроек — переносить
        // сам код блоков ради этого не пришлось.
        GridLayout {
            id: mainPage
            width: parent.width
            columns: 1
            columnSpacing: 0
            rowSpacing: 9
            opacity: (view.preview || view.sys.page === "main") ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

            // заголовок с шестернёй: быстрый переход в настройки
            RowLayout {
                objectName: "cc-clock"
                Layout.row: view.ccRow("clock")
                Layout.column: 0
                Layout.fillWidth: true
                spacing: 10

                // часы: клик открывает календарь
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 12
                    color: clockMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 4
                        spacing: 10

                        Text {
                            visible: !view.sys.themeNothing
                            text: view.sys.timeText
                            color: view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 8; bold: true }
                        }

                        // Nothing: крупные часы точками, секунды — мелким
                        // числом сбоку. Секунды здесь всегда, независимо от
                        // настройки «показывать секунды»: та про часы в
                        // строке, а это отдельное число рядом с ними.
                        RowLayout {
                            visible: view.sys.themeNothing
                            spacing: 5

                            DotText {
                                Layout.alignment: Qt.AlignVCenter
                                value: view.sys.timeText
                                size: view.sys.dotHBig
                                color: view.sys.colFg
                            }
                            DotText {
                                // по верхнему краю, а не по центру: мелкое
                                // число посередине крупных часов читалось бы
                                // как их часть
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 1
                                // Только когда секунд нет в самих часах. С
                                // включённой настройкой «показывать секунды»
                                // они уже стоят в timeText, и это число
                                // повторяло их второй раз: «19:36:42 42».
                                visible: !view.sys.cfg.clockSeconds
                                value: view.sys.secText
                                size: view.sys.dotHSmall
                                color: view.sys.colMuted
                            }
                        }
                        ColumnLayout {
                            spacing: -1
                            Text {
                                text: view.sys.dateLong
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                            }
                            Text {
                                visible: view.sys.cfg.featCalendar
                                text: view.sys.tr("Календарь")
                                color: clockMa.containsMouse ? view.sys.colOn
                                                            : Qt.rgba(1, 1, 1, 0.28)
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5 }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }
                    }

                    MouseArea {
                        id: clockMa
                        anchors.fill: parent
                        hoverEnabled: view.sys.cfg.featCalendar
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.togglePage("cal")
                    }
                }

            }

            // ------------------------------- Wi-Fi · Bluetooth · звук в строчку
            // Три самых частых переключателя занимали три полосы подряд.
            // Теперь это одна строка, а громкость правится прямо в плитке.
            RowLayout {
                objectName: "cc-toggles"
                Layout.row: view.ccRow("toggles")
                Layout.column: 0
                Layout.fillWidth: true
                spacing: 8

                // Wi-Fi и Bluetooth делят строку поровну. Раньше рядом с ними
                // стоял ещё и звук, и три плитки в ряд ужимали каждую до
                // ширины, на которой не помещалось имя сети.
                // Воткнут кабель — плитка показывает проводную сеть: связь
                // идёт по нему, и антенна Wi-Fi поверх работающего кабеля
                // вводила бы в заблуждение. Кабель вынули — плитка сама
                // возвращается к Wi-Fi. Одинаково на ноутбуке и на ПК: там,
                // где беспроводного адаптера нет вовсе, она просто всегда
                // проводная.
                MiniTile {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 56
                    // Кабель рисуется фигурой, Wi-Fi остаётся знаком шрифта:
                    // антенна в Nerd Font сделана хорошо, а дерева сети без
                    // перекладины во всю ширину там просто нет.
                    iconItem: view.sys.wiredOn ? lanShape : null
                    icon: view.sys.wifiOn ? (view.sys.wifiQuality > 66 ? "󰤨"
                                           : view.sys.wifiQuality > 33 ? "󰤥" : "󰤟") : "󰤮"
                    // подключены — в заголовке имя сети, иначе обычное «Wi-Fi»
                    label: view.sys.wiredOn ? view.sys.tr("Проводная сеть")
                         : (view.sys.wifiOn && view.sys.wifiSsid.length)
                           ? view.sys.wifiSsid : "Wi-Fi"
                    sub: view.sys.wiredOn ? view.sys.wiredName
                       : !view.sys.wifiOn ? view.sys.tr("Выключен")
                       : (view.sys.wifiSsid.length
                          ? view.sys.wifiQuality + "%"
                          : view.sys.tr("Не подключено"))
                    on: view.sys.wiredOn || view.sys.wifiOn
                    // Значок кабеля ничего не переключает: проводную сеть
                    // выключают кабелем, а не кнопкой. Wi-Fi при этом остаётся
                    // доступен из тела плитки — он мог понадобиться и рядом
                    // с кабелем.
                    onIconClicked: if (!view.sys.wiredOn) view.sys.toggleWifi()
                    onBodyClicked: {
                        // страница сетей могла быть отключена установщиком —
                        // тогда плитка только переключает Wi-Fi
                        if (!view.sys.wifiOn || !view.sys.cfg.featWifi) return;
                        view.sys.openSub("wifi");
                        view.sys.refreshWifiList();
                        view.sys.scanWifi();
                    }
                }

                MiniTile {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 56
                    icon: view.sys.btOn ? "󰂯" : "󰂲"
                    // подключено устройство — его имя вместо «Bluetooth»
                    label: (view.sys.btOn && view.sys.btConnectedName.length)
                           ? view.sys.btConnectedName : "Bluetooth"
                    sub: !view.sys.btOn ? view.sys.tr("Выключен")
                       : (view.sys.btConnectedName.length
                          ? (view.sys.btConnectedBattery >= 0
                             ? "󰥉 " + view.sys.btConnectedBattery + "%"
                             : view.sys.tr("Подключено"))
                          : view.sys.tr("Нет подключений"))
                    on: view.sys.btOn
                    // Синий у Bluetooth — примета его собственного значка, но
                    // на теме Nothing цветного акцента нет вовсе, и одна
                    // голубая плитка среди чёрно-белых выбивается.
                    accent: view.sys.themeNothing ? view.sys.colOn : "#0ea5e9"
                    onIconClicked: view.sys.toggleBt()
                    onBodyClicked: {
                        if (!view.sys.btOn || !view.sys.cfg.featBluetooth) return;
                        view.sys.openSub("bt");
                        view.sys.scanBt();
                    }
                }

                // Nothing: звук встаёт третьим в эту же строку, а сеть с
                // Bluetooth сжимаются и уезжают левее. Место звука в строке
                // ползунков при этом освобождается — карточка не должна
                // оказаться в панели дважды.
                //
                // Доля та же, что у соседей: строка делится на три равные
                // части. Раньше звуку отводили меньше, чтобы не обрезать имена
                // сети и устройства, — но обрезать их приходилось всё равно,
                // только неровными карточками вместо честного многоточия.
                VolCard {
                    visible: view.sys.cfg.featAudio
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 56
                }
            }

            // ------------------------------------------- громкость и яркость
            // Две одинаковые карточки в одной строке. На ПК клавиш яркости на
            // клавиатуре нет, а на мониторе она прячется в аппаратном меню —
            // эта дорожка единственный быстрый способ до неё добраться.
            // Экранов, отвечающих на запрос яркости, может не быть вовсе —
            // тогда в строке остаётся один звук.
            RowLayout {
                objectName: "cc-sliders"
                Layout.row: view.ccRow("sliders")
                Layout.column: 0
                Layout.fillWidth: true
                spacing: 8
                // Звук отсюда уехал наверх, в строку с сетью и Bluetooth, и
                // в этой строке осталась одна яркость. Управляется она не
                // везде: на настольной машине без DDC экранов в списке нет
                // вовсе, и строка прячется целиком — пустая, она всё равно
                // съедала бы промежуток сетки.
                visible: (view.sys.brightList || []).length > 0

                Repeater {
                    model: view.sys.brightList

                    BrightCard {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 56
                        bid:  modelData.id
                        bpct: modelData.pct
                        bname: (view.sys.brightList || []).length > 1 ? modelData.name : ""
                    }
                }
            }

            // ----------------------------------------------- играющий трек
            // Стоит под переключателями: пока что-то играет, трек с кнопками
            // и эквалайзером во всю ширину заменяет отдельную страницу
            // плеера, которая раньше открывалась по наведению.
            Rectangle {
                objectName: "cc-media"
                Layout.row: view.ccRow("media")
                Layout.column: 0
                id: mediaCard
                readonly property var p: view.sys.player

                visible: view.sys.mediaActive && view.sys.cfg.featPlayer
                Layout.fillWidth: true
                Layout.preferredHeight: 124
                radius: 16
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: view.sys.colLine
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 11
                    anchors.rightMargin: 12
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 11

                        // обложка — клик открывает подробную страницу плеера
                        Rectangle {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            radius: 10
                            color: Qt.rgba(1, 1, 1, 0.07)

                            Image {
                                id: cardArt
                                anchors.fill: parent
                                source: view.sys.mediaArt
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 120
                                // маска, чтобы у обложки были скруглённые углы,
                                // а не острые поверх скруглённого плейсхолдера
                                visible: false
                                layer.enabled: true
                            }
                            Item {
                                id: cardArtMask
                                anchors.fill: parent
                                visible: false
                                layer.enabled: true
                                Rectangle { anchors.fill: parent; radius: 10; color: "#ffffff" }
                            }
                            MultiEffect {
                                anchors.fill: parent
                                source: cardArt
                                maskEnabled: true
                                maskSource: cardArtMask
                                visible: cardArt.status === Image.Ready
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: cardArt.status !== Image.Ready
                                text: "󰝚"
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 18 }
                            }
                            // клик по обложке — пауза: отдельной страницы
                            // плеера больше нет, всё управление здесь
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (mediaCard.p) mediaCard.p.togglePlaying()
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: mediaCard.p ? mediaCard.p.trackTitle : ""
                                color: view.sys.colFg
                                elide: Text.ElideRight
                                font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: mediaCard.p ? mediaCard.p.trackArtist : ""
                                color: view.sys.colMuted
                                elide: Text.ElideRight
                                font { family: view.sys.fontFam; pixelSize: 11 }
                            }
                        }

                        MediaBtn {
                            icon: "󰒮"
                            enabledAction: mediaCard.p ? mediaCard.p.canGoPrevious : false
                            onAct: if (mediaCard.p) mediaCard.p.previous()
                        }
                        MediaBtn {
                            icon: mediaCard.p && mediaCard.p.isPlaying ? "󰏤" : "󰐊"
                            primary: true
                            enabledAction: mediaCard.p ? mediaCard.p.canTogglePlaying : false
                            onAct: if (mediaCard.p) mediaCard.p.togglePlaying()
                        }
                        MediaBtn {
                            icon: "󰒭"
                            enabledAction: mediaCard.p ? mediaCard.p.canGoNext : false
                            onAct: if (mediaCard.p) mediaCard.p.next()
                        }
                    }

                    // ------------------- полоса продолжительности с cava
                    // Эквалайзер и есть ползунок: пройденная часть спектра
                    // светится акцентом, остаток — приглушённый. Так плашка
                    // не растёт на две отдельные полосы, а перемотка видна
                    // прямо по звуку.
                    //
                    // Оба слоя берут один и тот же поток из CavaSource,
                    // поэтому полосы в них совпадают кадр в кадр, и стык
                    // между «сыграно» и «осталось» не видно.
                    Item {
                        id: seek
                        readonly property var p: mediaCard.p
                        readonly property real dur: seek.p ? Math.max(0, seek.p.length) : 0
                        readonly property bool usable:
                            seek.p !== null && seek.dur > 0
                            && seek.p.positionSupported && seek.p.canSeek
                        readonly property real frac: seek.dur > 0
                                ? Math.max(0, Math.min(1, seek.pos / seek.dur)) : 0

                        // позиция, которую показываем: секунды
                        property real pos: 0
                        property bool dragging: false
                        // до первого опроса анимация выключена: иначе на
                        // раскрытии полоса ехала от нуля к текущему месту
                        property bool primed: false

                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        visible: seek.p !== null
                        // панель закрыли — при следующем раскрытии позиция
                        // должна встать на место сразу, а не доезжать
                        Component.onDestruction: seek.primed = false

                        // MPRIS отдаёт позицию только по запросу: между
                        // опросами полосу двигает линейная анимация, иначе
                        // она прыгала бы раз в полсекунды. На перетаскивании
                        // анимация выключена — ручка идёт точно за курсором.
                        Behavior on pos {
                            enabled: seek.primed && !seek.dragging
                            NumberAnimation { duration: 520; easing.type: Easing.Linear }
                        }
                        Timer {
                            interval: 500
                            repeat: true
                            running: seek.visible && seek.p !== null
                            triggeredOnStart: true
                            onTriggered: {
                                if (seek.p === null) return;
                                seek.p.positionChanged();
                                if (seek.dragging) return;
                                seek.pos = seek.p.position;
                                seek.primed = true;
                            }
                        }
                        Connections {
                            target: mediaCard.p
                            ignoreUnknownSignals: true
                            // сменился трек — начинаем с нуля, без переезда
                            function onTrackTitleChanged() {
                                seek.dragging = false;
                                seek.primed = false;   // новый трек — снова без переезда
                                seek.pos = 0;
                            }
                        }

                        function fracOf(x) {
                            return Math.max(0, Math.min(1, x / Math.max(1, seek.width)));
                        }

                        // остаток трека — приглушённые полосы
                        WaveBars {
                            id: barsRest
                            anchors.fill: parent
                            barCount: 46
                            gap: 3
                            barColor: Qt.rgba(1, 1, 1, 0.22)
                            active: seek.p ? seek.p.isPlaying : false
                        }

                        // сыграно — те же полосы акцентом, обрезанные по позиции
                        Item {
                            width: seek.width * seek.frac
                            height: seek.height
                            clip: true
                            WaveBars {
                                width: seek.width
                                height: seek.height
                                barCount: 46
                                gap: 3
                                barColor: view.sys.colOn
                                // Оба слоя живые: с active: false верхние полосы
                                // стояли на месте, и в ритм двигались только
                                // серые из-под них. Поток у CavaSource общий и
                                // считается по ссылкам, второго процесса нет.
                                active: seek.p ? seek.p.isPlaying : false
                            }
                        }

                        // тонкая линия по низу: без неё пустые паузы в звуке
                        // выглядели бы обрывом полосы.
                        // На теме Nothing её нет: там дорожка — только сам
                        // спектр, и подчёркивание снизу спорит с ним.
                        Rectangle {
                            visible: !view.sys.themeNothing
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 2
                            radius: 1
                            color: Qt.rgba(1, 1, 1, 0.12)
                            Rectangle {
                                width: parent.width * seek.frac
                                height: parent.height
                                radius: 1
                                color: view.sys.colOn
                            }
                        }

                        // Ручка — вертикальная риска на позиции.
                        //
                        // На теме Nothing она не висит постоянно, а появляется
                        // под курсором. Совсем убрать её нельзя: перемотка
                        // осталась, а без всякого отклика непонятно, куда
                        // попадёшь, — и промах слышен сразу. Пока мышь мимо,
                        // никакой черты поверх спектра нет.
                        Rectangle {
                            x: seek.width * seek.frac - width / 2
                            width: seekMa.pressed ? 3 : 2
                            height: parent.height
                            radius: 1.5
                            color: "#ffffff"
                            opacity: !seek.usable ? (view.sys.themeNothing ? 0 : 0.3)
                                   : (seekMa.containsMouse || seekMa.pressed) ? 1
                                   : (view.sys.themeNothing ? 0 : 0.75)
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                            Behavior on width { NumberAnimation { duration: 120 } }
                        }

                        MouseArea {
                            id: seekMa
                            anchors.fill: parent
                            anchors.margins: -3
                            hoverEnabled: true
                            preventStealing: true
                            enabled: seek.usable
                            cursorShape: seek.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onPressed: mouse => {
                                seek.dragging = true;
                                seek.pos = seek.fracOf(mouse.x) * seek.dur;
                            }
                            onPositionChanged: mouse => {
                                if (!pressed) return;
                                seek.pos = seek.fracOf(mouse.x) * seek.dur;
                            }
                            onReleased: mouse => {
                                // отправляем плееру уже на отпускании: на каждом
                                // кадре MPRIS-клиент начинает спорить и дёргать
                                // позицию назад
                                if (seek.usable) seek.p.position = seek.pos;
                                seek.dragging = false;
                            }
                            onCanceled: seek.dragging = false
                        }
                    }

                    // время: прошло и всего
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: -6
                        visible: seek.visible && seek.dur > 0
                        Text {
                            visible: !view.sys.themeNothing
                            text: view.fmtTime(seek.pos)
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 10 }
                        }
                        DotText {
                            visible: view.sys.themeNothing
                            value: view.fmtTime(seek.pos)
                            size: view.sys.dotHSmall
                            color: view.sys.colMuted
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            visible: !view.sys.themeNothing
                            text: view.fmtTime(seek.dur)
                            color: Qt.rgba(1, 1, 1, 0.28)
                            font { family: view.sys.fontFam; pixelSize: 10 }
                        }
                        DotText {
                            visible: view.sys.themeNothing
                            value: view.fmtTime(seek.dur)
                            size: view.sys.dotHSmall
                            color: Qt.rgba(1, 1, 1, 0.28)
                        }
                    }
                }
            }

            // ------------------------------- запись экрана · режим батареи
            // Режимы питания больше не занимают отдельную полосу из трёх
            // сегментов: они уехали на страницу батареи, а сюда встала одна
            // плитка рядом с записью.
            RowLayout {
                id: powerRow
                objectName: "cc-power"
                Layout.row: view.ccRow("power")
                Layout.column: 0
                Layout.fillWidth: true
                spacing: 8

                // На теме Nothing в этой строке стоит ещё и сводка нагрузки в
                // три строки — плитки растут под неё, иначе соседи оказались
                // бы разной высоты.
                readonly property int tileH: 76

                // Доли, а не свободный рост. RowLayout раздаёт лишнее место
                // пропорционально желаемой ширине, а у плитки она своя (140),
                // тогда как у сводки — ноль: её содержимое прижато якорями.
                // Без явных долей плитка забирала строку целиком, а от сводки
                // оставалась полоска в несколько пикселей у самого края.
                // На теме Nothing вместо плитки стоит плашка с кнопкой и
                // отсчётом: частота кадров, которую плитка показывала до
                // начала записи, приходит из настроек и меняется раз в жизнь.
                RecordCard {
                    visible: view.sys.cfg.featRecord
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: powerRow.tileH
                }


                // Плитка батареи. На ПК её нет совсем: заряда не существует, а
                // профили питания без батареи показывают одно и то же — плитка
                // с вечной надписью «От сети» занимала место зря.
                MiniTile {
                    visible: view.sys.showBattery || view.sys.showPowerProfiles
                    Layout.fillWidth: true
                    // Пополам с записью: две карточки в строке делят её
                    // поровну. Прежняя доля в 1.35 повторяла ширину сводки
                    // нагрузки, но рядом с записью читалась просто как
                    // перекос — одна карточка заметно шире другой без причины.
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: powerRow.tileH
                    icon: view.sys.batteryPresent ? view.sys.batteryLevelIcon
                                                  : String.fromCodePoint(0xF0241)
                    label: view.sys.batteryPresent
                           ? view.sys.batteryPct + "%" : view.sys.tr("Батарея")
                    // подпись — состояние питания и текущий режим, без
                    // прогнозов «сколько осталось»: UPower врёт на глазах
                    sub: view.sys.batteryCharging ? view.sys.tr("Заряжается")
                       : view.sys.acOnline ? view.sys.tr("От сети")
                                           : view.sys.profileLabel
                    on: view.sys.batteryCharging || view.sys.acOnline
                    wave: view.sys.batteryCharging
                    waveLevel: view.sys.batteryPct / 100
                    accent: view.sys.batteryPct <= 15 && !view.sys.acOnline
                            ? view.sys.colCrit : view.sys.colOk
                    onIconClicked: view.sys.openSub("battery")
                    onBodyClicked: view.sys.openSub("battery")
                }

                // Сводка нагрузки стоит только на настольной машине. На
                // ноутбуке её место занимает батарея: заряд там меняется сам
                // и решает, что делать дальше, а загрузка процессора — нет.
                // Три карточки в ряд ужимают каждую до нечитаемого.
                //
                // Доля больше единицы: здесь три строки с полосками, и им
                // нужнее ширина, чем плитке записи с двумя короткими
                // подписями.
                LoadCard {
                    visible: !view.sys.batteryPresent
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1.35
                    Layout.preferredHeight: powerRow.tileH
                }
            }

            // -------------------------------- не спать + кнопки-иконки
            // Замок, уведомления и настройки уехали сюда из правого верхнего
            // угла: одна нижняя полоса вместо значков, спорящих с часами.
            RowLayout {
                objectName: "cc-quick"
                Layout.row: view.ccRow("quick")
                Layout.column: 0
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                id: awakeRow
                // Янтарный «не спать» — цвет кофе, и на прочих темах он к
                // месту. На Nothing цветного акцента нет вовсе, и одна
                // оранжевая полоса внизу чёрно-белой панели бросается в
                // глаза сильнее, чем сам режим того стоит.
                readonly property color tint: view.sys.themeNothing
                                              ? view.sys.colOn : "#f59e0b"

                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 12
                color: view.sys.keepAwake
                       ? Qt.rgba(awakeRow.tint.r, awakeRow.tint.g, awakeRow.tint.b, 0.16)
                       : (awakeMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
                border.color: view.sys.keepAwake
                              ? Qt.rgba(awakeRow.tint.r, awakeRow.tint.g, awakeRow.tint.b, 0.40)
                              : view.sys.colLine
                border.width: 1
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 13
                    anchors.rightMargin: 13
                    spacing: 11

                    Glyph {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        glyph: String.fromCodePoint(view.sys.keepAwake ? 0xF0176 : 0xF0177)
                        color: view.sys.keepAwake ? awakeRow.tint : view.sys.colMuted
                        fontFam: view.sys.fontFam
                        size: view.sys.iconSize + 2
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Coffee mode"
                        color: view.sys.keepAwake ? view.sys.colFg : view.sys.colMuted
                        font {
                            family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2
                            bold: view.sys.keepAwake
                        }
                    }
                    // переключатель
                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 21
                        radius: 11
                        color: view.sys.keepAwake ? awakeRow.tint : Qt.rgba(1, 1, 1, 0.14)
                        Behavior on color { ColorAnimation { duration: 180 } }
                        Rectangle {
                            width: 17; height: 17; radius: 9
                            y: 2
                            x: view.sys.keepAwake ? parent.width - width - 2 : 2
                            // на белой дорожке белый кружок пропадает
                            color: view.sys.keepAwake
                                   ? view.sys.fgOn(awakeRow.tint) : "#ffffff"
                            Behavior on x {
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }

                MouseArea {
                    id: awakeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.keepAwake = !view.sys.keepAwake
                }
            }

            // кнопка питания: меню выключения, перезагрузки, блокировки и сна
            IconBtn {
                glyph: String.fromCodePoint(0xF0425)
                tip: view.sys.tr("Питание")
                activeColor: view.sys.colCrit
                onAct: view.sys.togglePage("power")
            }

            // колокольчик: активные уведомления и история
            IconBtn {
                visible: view.sys.cfg.featNotifications
                glyph: String.fromCodePoint(view.sys.dnd ? 0xF009B : 0xF009A)
                tip: view.sys.dnd ? view.sys.tr("Не беспокоить") : view.sys.tr("Уведомления")
                badge: view.sys.notifications.count
                onAct: view.sys.togglePage("notif")
            }

            IconBtn {
                glyph: String.fromCodePoint(0xF0493)
                tip: view.sys.tr("Настройки")
                onAct: view.sys.togglePage("settings")
            }
            }

            // ------------------------------------------------ системный трей
            RowLayout {
                objectName: "cc-tray"
                Layout.row: view.ccRow("tray")
                Layout.column: 0
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 8
                visible: view.sys.trayItems.values.length > 0

                Text {
                    text: view.sys.tr("Трей")
                    color: view.sys.colMuted
                    font {
                        family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4
                        bold: true; capitalization: Font.AllUppercase; letterSpacing: 1
                    }
                }

                Repeater {
                    model: view.sys.trayItems

                    Rectangle {
                        id: trayBtn
                        required property var modelData

                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        z: trayMa.containsMouse ? 10 : 0
                        radius: 10
                        color: trayMa.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.05)
                        border.color: view.sys.colLine
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        scale: trayMa.pressed ? 0.9 : 1.0
                        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

                        Image {
                            anchors.fill: parent
                            anchors.margins: 7
                            source: String(trayBtn.modelData.icon || "")
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        MouseArea {
                            id: trayMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            onClicked: mouse => {
                                // ПКМ — контекстное меню приложения (Telegram и т.п.)
                                if (mouse.button === Qt.RightButton) {
                                    if (!trayBtn.modelData.hasMenu) return;
                                    view.sys.trayMenuItem = trayBtn.modelData;
                                    view.sys.page = "traymenu";
                                    view.sys.holdOpen = true;
                                    return;
                                }
                                if (mouse.button === Qt.MiddleButton)
                                    trayBtn.modelData.secondaryActivate();
                                else
                                    trayBtn.modelData.activate();
                                view.sys.collapse();
                            }
                        }

                        // Свой тултип вместо системного: та же чёрная капсула,
                        // что и вся пилюля.
                        Rectangle {
                            id: tip
                            readonly property string label:
                                String(trayBtn.modelData.tooltipTitle
                                       || trayBtn.modelData.title || "")

                            visible: opacity > 0.01
                            opacity: (trayMa.containsMouse && label.length) ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }

                            width: tipText.implicitWidth + 20
                            height: 26
                            radius: 13
                            x: (parent.width - width) / 2
                            y: -height - 8
                            color: Qt.rgba(0.04, 0.04, 0.05, 0.96)
                            border.color: view.sys.colLine
                            border.width: 1

                            scale: trayMa.containsMouse ? 1 : 0.92
                            transformOrigin: Item.Bottom
                            Behavior on scale {
                                NumberAnimation { duration: 160; easing.type: Easing.OutBack }
                            }

                            Text {
                                id: tipText
                                anchors.centerIn: parent
                                text: tip.label
                                color: view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: 11 }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }

        // ---------------------------------------------------------- батарея
        // Режимы питания плюс всё, что UPower знает про заряд: сколько
        // осталось работы (или до полной зарядки), ёмкость и износ.
        ColumnLayout {
            id: battPage
            width: parent.width
            spacing: 8
            opacity: view.sys.page === "battery" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

            Header {
                title: view.sys.tr("Батарея")
                onBack: view.sys.page = "main"
            }

            // крупная строка состояния: процент и что происходит сейчас
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: view.sys.colLine
                border.width: 1

                readonly property color tint:
                    view.sys.batteryCharging || view.sys.acOnline ? view.sys.colOk
                  : view.sys.batteryPct <= 15 ? view.sys.colCrit
                  : view.sys.colFg

                // пока подключена зарядка — плашка налита живой волной
                ChargeWave {
                    anchors.fill: parent
                    radius: parent.radius
                    tint: view.sys.colOk
                    level: view.sys.batteryPct / 100
                    running: view.sys.batteryCharging
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    Glyph {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        glyph: view.sys.batteryLevelIcon
                        color: parent.parent.tint
                        fontFam: view.sys.fontFam
                        size: view.sys.iconSize + 3
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: view.sys.batteryPct + "%"
                            color: parent.parent.parent.tint
                            font { family: view.sys.fontFam; pixelSize: 18; bold: true }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: view.sys.batteryCharging
                                  ? view.sys.tr("Заряжается")
                                  : view.sys.acOnline ? view.sys.tr("От сети")
                                                      : view.sys.profileLabel
                            color: view.sys.colMuted
                            elide: Text.ElideRight
                            font { family: view.sys.fontFam; pixelSize: 11 }
                        }
                    }

                    // Индикатор питания вместо прогнозов времени: молния,
                    // когда идёт зарядка, вилка — когда просто от сети.
                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        Layout.alignment: Qt.AlignVCenter
                        radius: 15
                        visible: view.sys.batteryCharging || view.sys.acOnline
                        color: Qt.rgba(view.sys.colOk.r, view.sys.colOk.g,
                                       view.sys.colOk.b, 0.18)

                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(
                                      view.sys.batteryCharging ? 0xF0241 : 0xF06A5)
                            color: view.sys.colOk
                            font { family: view.sys.fontFam; pixelSize: 15 }
                            // пока заряжается — молния мягко пульсирует
                            SequentialAnimation on opacity {
                                running: view.sys.batteryCharging
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.4; duration: 750; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 750; easing.type: Easing.InOutSine }
                            }
                            onVisibleChanged: if (!visible) opacity = 1
                        }
                    }
                }
            }

            // режимы питания — те самые три сегмента, теперь живут здесь
            RowLayout {
                visible: view.sys.showPowerProfiles
                Layout.fillWidth: true
                spacing: 8

                PowerSeg {
                    icon: "󰾆"
                    label: view.sys.tr("Экономия")
                    profile: "power-saver"
                    accent: view.sys.colOk
                }
                PowerSeg {
                    icon: "󰾅"
                    label: view.sys.tr("Баланс")
                    profile: "balanced"
                    accent: view.sys.colOn
                }
                PowerSeg {
                    icon: "󰓅"
                    label: view.sys.tr("Максимум")
                    profile: "performance"
                    accent: view.sys.colWarn
                }
            }

            // мелкие цифры — ёмкость, износ и текущий расход, в одну полосу
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: view.sys.batteryPresent

                BattStat {
                    label: view.sys.tr("Ёмкость")
                    value: view.sys.batteryCapacity > 0
                           ? view.sys.batteryCapacity.toFixed(1) + " Wh" : "—"
                }
                BattStat {
                    label: view.sys.tr("Износ")
                    value: view.sys.batteryHealth > 0
                           ? view.sys.batteryHealth + "%" : "—"
                }
                BattStat {
                    label: view.sys.batteryCharging ? "󰐥" : "󰚥"
                    value: Math.abs(view.sys.batteryRate) > 0.05
                           ? Math.abs(view.sys.batteryRate).toFixed(1) + " W" : "—"
                }
            }
        }

        // ------------------------------------------------------------ Wi-Fi
        ColumnLayout {
            id: wifiPage
            width: parent.width
            spacing: 7

            // Что за сеть выбрана правой кнопкой и что с ней можно сделать.
            property string menuSsid: ""
            property bool menuConnected: false
            property bool menuKnown: false

            opacity: view.sys.page === "wifi" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

            Header {
                title: view.sys.tr("Сети Wi-Fi")
                busy: view.sys.wifiBusy
                onBack: { view.sys.page = "main"; passwordFor = ""; }
                onRefresh: view.sys.scanWifi()
            }

            // ввод пароля для выбранной сети
            property string passwordFor: ""

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                visible: wifiPage.passwordFor.length > 0
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.06)
                border.color: view.sys.colLine
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 11
                    anchors.rightMargin: 7
                    spacing: 8

                    Text {
                        text: "󰌾"
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 14 }
                    }
                    TextField {
                        id: pwField
                        Layout.fillWidth: true
                        placeholderText: view.sys.tr("Пароль от «") + wifiPage.passwordFor + "»"
                        echoMode: TextInput.Password
                        color: view.sys.colFg
                        placeholderTextColor: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 12 }
                        background: null
                        onAccepted: connectBtn.go()
                    }
                    Rectangle {
                        id: connectBtn
                        function go() {
                            if (!pwField.text.length) return;
                            view.sys.connectWifi(wifiPage.passwordFor, pwField.text);
                            wifiPage.passwordFor = "";
                            pwField.text = "";
                            view.sys.holdOpen = false;
                        }
                        Layout.preferredWidth: 34; Layout.preferredHeight: 32
                        radius: 10
                        color: pwField.text.length ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.10)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent; text: ""
                            color: "#ffffff"
                            font { family: view.sys.fontFam; pixelSize: 13 }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: connectBtn.go()
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: view.sys.wifiError.length > 0
                text: view.sys.wifiError
                color: view.sys.colCrit
                font { family: view.sys.fontFam; pixelSize: 11 }
            }

            // список сетей
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: view.sys.wifiNetworks
                    Row1 {
                        required property var model
                        icon: model.quality > 66 ? "󰤨" : model.quality > 33 ? "󰤥" : "󰤟"
                        title: model.ssid
                        sub: (model.security === "open" ? view.sys.tr("Открытая") : view.sys.tr("Защищённая"))
                             + " · " + model.quality + "%"
                             + (model.known ? view.sys.tr(" · сохранена") : "")
                        highlight: model.connected
                        onActivated: {
                            if (model.connected) return;
                            if (model.security === "open" || model.known) {
                                view.sys.connectWifi(model.ssid, "");
                            } else {
                                wifiPage.passwordFor = model.ssid;
                                view.sys.holdOpen = true;
                                pwFocus.restart();
                            }
                        }
                        onMenuRequested: (mx, my) => {
                            // меню имеет смысл только там, где есть что делать:
                            // отключиться можно от текущей, забыть — сохранённую
                            if (!model.connected && !model.known) return;
                            wifiPage.menuSsid = model.ssid;
                            wifiPage.menuConnected = model.connected;
                            wifiPage.menuKnown = model.known;
                            view.sys.page = "netmenu";
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: view.sys.wifiNetworks.count === 0
                text: view.sys.wifiBusy ? view.sys.tr("Поиск сетей…") : view.sys.tr("Сети не найдены")
                color: view.sys.colMuted
                horizontalAlignment: Text.AlignHCenter
                font { family: view.sys.fontFam; pixelSize: 11 }
            }

            Timer { id: pwFocus; interval: 80; onTriggered: pwField.forceActiveFocus() }

        }

        // ------------------------------------------------- меню сети
        // Отдельной страницей, как меню трея: панель узкая, и всплывающее окно
        // поверх списка пришлось бы двигать, чтобы оно не уезжало за край.
        // Страница открывается по правой кнопке на сети и умеет ровно то, чего
        // нет в самом списке: отключиться и забыть.
        ColumnLayout {
            id: netMenuPage
            width: parent.width
            spacing: 3
            opacity: view.sys.page === "netmenu" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

            Header {
                title: wifiPage.menuSsid.length ? wifiPage.menuSsid : view.sys.tr("Сеть")
                busy: view.sys.wifiBusy
                onBack: view.sys.page = "wifi"
                onRefresh: {}
            }

            Row1 {
                visible: wifiPage.menuConnected
                icon: "󰖪"
                title: view.sys.tr("Отключиться")
                sub: view.sys.tr("Связь разорвётся, сеть останется сохранённой")
                onActivated: {
                    view.sys.disconnectWifi();
                    view.sys.page = "wifi";
                }
            }

            Row1 {
                visible: wifiPage.menuKnown
                icon: "󰅖"
                title: view.sys.tr("Забыть сеть")
                sub: view.sys.tr("Больше не подключаться самому")
                onActivated: {
                    view.sys.forgetWifi(wifiPage.menuSsid);
                    view.sys.page = "wifi";
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: !wifiPage.menuConnected && !wifiPage.menuKnown
                text: view.sys.tr("Для этой сети ничего не сохранено.")
                color: view.sys.colMuted
                horizontalAlignment: Text.AlignHCenter
                font { family: view.sys.fontFam; pixelSize: 11 }
            }
        }

        // ------------------------------------------- контекстное меню трея
        ColumnLayout {
            id: trayPage
            width: parent.width
            spacing: 3
            opacity: view.sys.page === "traymenu" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

            // цепочка вложенных подменю: последний элемент — текущее меню
            property var chain: []
            readonly property var rootHandle:
                view.sys.trayMenuItem ? view.sys.trayMenuItem.menu : null
            readonly property var handle:
                chain.length > 0 ? chain[chain.length - 1] : rootHandle

            // новая иконка — начинаем с её корневого меню.
            // Присваиваем только когда есть что сбрасывать: иначе QML видит
            // цикл chain -> handle -> chain и ругается на каждом открытии.
            onRootHandleChanged: if (chain.length > 0) chain = []

            QsMenuOpener {
                id: menuOpener
                menu: trayPage.handle
            }

            Header {
                title: view.sys.trayMenuItem
                       ? String(view.sys.trayMenuItem.tooltipTitle
                                || view.sys.trayMenuItem.title || view.sys.tr("Меню"))
                       : view.sys.tr("Меню")
                busy: false
                onBack: {
                    if (trayPage.chain.length > 0) {
                        var c = trayPage.chain.slice();
                        c.pop();
                        trayPage.chain = c;
                    } else {
                        view.sys.page = "main";
                        view.sys.trayMenuItem = null;
                    }
                }
                onRefresh: {}
            }

            Repeater {
                model: menuOpener.children

                // разделитель и обычный пункт — в одном делегате: Repeater
                // не умеет выбирать компонент по данным модели
                Item {
                    id: entry
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: modelData.isSeparator ? 9 : 34

                    Rectangle {
                        visible: entry.modelData.isSeparator
                        height: 1
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: view.sys.colLine
                    }

                    Rectangle {
                        visible: !entry.modelData.isSeparator
                        anchors.fill: parent
                        radius: 10
                        color: entryMa.containsMouse && entry.modelData.enabled
                               ? view.sys.colHover : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 11
                            anchors.rightMargin: 11
                            spacing: 9

                            // галочка/радио для переключаемых пунктов
                            Text {
                                visible: entry.modelData.buttonType !== QsMenuButtonType.None
                                text: entry.modelData.checkState === Qt.Checked
                                      ? "󰄬" : "󰝦"
                                color: entry.modelData.checkState === Qt.Checked
                                       ? view.sys.colOn : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 12 }
                            }

                            Image {
                                visible: String(entry.modelData.icon || "").length > 0
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                source: String(entry.modelData.icon || "")
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            Text {
                                Layout.fillWidth: true
                                text: String(entry.modelData.text || "")
                                color: entry.modelData.enabled
                                       ? view.sys.colFg : view.sys.colMuted
                                elide: Text.ElideRight
                                font { family: view.sys.fontFam; pixelSize: 12 }
                            }

                            // стрелка у подменю
                            Text {
                                visible: entry.modelData.hasChildren
                                text: ""
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 11 }
                            }
                        }

                        MouseArea {
                            id: entryMa
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: entry.modelData.enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (entry.modelData.hasChildren) {
                                    var c = trayPage.chain.slice();
                                    c.push(entry.modelData);
                                    trayPage.chain = c;
                                    return;
                                }
                                entry.modelData.triggered();
                                view.sys.collapse();
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !menuOpener.children || menuOpener.children.values.length === 0
                text: view.sys.tr("Меню пустое")
                color: view.sys.colMuted
                horizontalAlignment: Text.AlignHCenter
                font { family: view.sys.fontFam; pixelSize: 11 }
            }
        }

        // -------------------------------------------------------- Bluetooth
        ColumnLayout {
            id: btPage
            width: parent.width
            spacing: 7
            opacity: view.sys.page === "bt" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

            Header {
                title: view.sys.tr("Устройства Bluetooth")
                busy: view.sys.btAdapter ? view.sys.btAdapter.discovering : false
                onBack: view.sys.page = "main"
                onRefresh: view.sys.scanBt()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: view.sys.btDevices
                    Row1 {
                        id: row1
                        required property var modelData
                        icon: modelData.icon === "audio-headset" ? "󰋋"
                            : modelData.icon === "input-mouse" ? "󰦋"
                            : modelData.icon === "input-keyboard" ? "󰌌"
                            : modelData.icon === "phone" ? "󰄞" : "󰂯"
                        title: modelData.name || modelData.address
                        // Статус проходит через «Сопряжение…» и «Подключение…»,
                        // чтобы было видно, что происходит, а не «моргало».
                        sub: modelData.pairing ? view.sys.tr("Сопряжение…")
                           : modelData.state === BluetoothDeviceState.Connecting ? view.sys.tr("Подключение…")
                           : modelData.connected ? view.sys.tr("Подключено")
                           : (modelData.paired || modelData.bonded ? view.sys.tr("Сопряжено") : view.sys.tr("Доступно"))
                             + (modelData.batteryAvailable
                                ? " · " + Math.round(modelData.battery * 100) + "%" : "")
                        highlight: modelData.connected || modelData.pairing
                                   || modelData.state === BluetoothDeviceState.Connecting
                        onActivated: {
                            if (modelData.connected) { modelData.disconnect(); return; }
                            // Недоверенное устройство BlueZ подключает и тут же
                            // роняет; несопряжённое вообще не держится. Делаем
                            // доверенным, сопрягаем, а после сопряжения — сами
                            // подключаемся (pair не всегда доводит до звука).
                            modelData.trusted = true;
                            if (modelData.paired || modelData.bonded) modelData.connect();
                            else modelData.pair();
                        }
                        // как только сопряжение завершилось — подключаемся
                        property var dev: modelData
                        Connections {
                            target: row1.dev
                            function onPairedChanged() {
                                if (row1.dev.paired && !row1.dev.connected) row1.dev.connect();
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !view.sys.btDevices || view.sys.btDevices.values.length === 0
                text: (view.sys.btAdapter && view.sys.btAdapter.discovering)
                      ? view.sys.tr("Поиск устройств…") : view.sys.tr("Устройства не найдены")
                color: view.sys.colMuted
                horizontalAlignment: Text.AlignHCenter
                font { family: view.sys.fontFam; pixelSize: 11 }
            }
        }
    }

}
