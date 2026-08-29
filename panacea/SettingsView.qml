import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

// Окно настроек: слева поиск и список разделов, справа — сам раздел.
//
// Каждый раздел живёт отдельным файлом Set*.qml и получает только `sys`.
// Шапку с иконкой и описанием рисует каркас, поэтому страницы состоят из
// одних карточек и не повторяют друг за другом одну и ту же разметку.
Item {
    id: view

    property var sys
    // индекс раздела в view.sections
    property int tab: 0

    implicitWidth: 980
    implicitHeight: 620

    // ------------------------------------------------------------- разделы
    // keys — ключевые слова для поиска: по ним раздел находится, даже если
    // в названии нужного слова нет («темы» → Appearance, «wifi» → Control
    // Center).
    readonly property var sections: [
        { id: "bar",     title: "Bar & Island",   g: 0xF12E1, page: "SetBarIsland.qml",
          sub: view.sys.tr("Как остров стоит на кромке и во что он разворачивается."),
          keys: "notch island pill bar height width остров вырез капсула" },
        { id: "media",   title: "Media",          g: 0xF0387, page: "SetMedia.qml",
          sub: view.sys.tr("Плеер, обложки и то, что видно в свёрнутом острове."),
          keys: "player music cover звук плеер музыка обложка" },
        { id: "clock",   title: "Clock & Date",   g: 0xF0150, page: "SetClock.qml",
          sub: view.sys.tr("Формат времени, часовой пояс и подпись под ним."),
          keys: "clock time date timezone часы дата время пояс регион" },
        { id: "look",    title: "Appearance",     g: 0xF03D8, page: "SetAppearance.qml",
          sub: view.sys.tr("Тема, шрифты и то, из чего складывается геометрия."),
          keys: "theme font size radius spacing sounds audio haptics звуки звук звуковые эффекты тема шрифт цвет радиус отступ" },
        { id: "weather", title: "Weather",        g: 0xF0590, page: "SetWeather.qml",
          sub: view.sys.tr("Ключ, город и шкала для виджета погоды."),
          keys: "weather temperature city openweather api key celsius fahrenheit "
                + "погода температура город ключ цельсий фаренгейт градусы" },
        { id: "motion",  title: "Motion",         g: 0xF15B6, page: "SetMotion.qml",
          sub: view.sys.tr("Насколько быстро оболочка движется — и движется ли вообще."),
          keys: "animation speed bounce анимация скорость движение" },
        { id: "launch",  title: "Launcher",       g: 0xF0349, page: "SetLauncher.qml",
          sub: view.sys.tr("Поиск приложений и то, что он ищет кроме них."),
          keys: "launcher apps search запуск приложения поиск" },
        { id: "notif",   title: "Notifications",  g: 0xF009A, page: "SetNotifications.qml",
          sub: view.sys.tr("Сколько карточек висит на экране и как долго."),
          keys: "notifications dnd toast уведомления не беспокоить" },
        { id: "cc",      title: "Control Center", g: 0xF062E, page: "SetControlCenter.qml",
          sub: view.sys.tr("Раскладка быстрых настроек — плитки переставляются мышью."),
          keys: "quick settings tiles layout wifi bluetooth плитки быстрые" },
        { id: "lock",    title: "Lock Screen",    g: 0xF033E, page: "SetLock.qml",
          sub: view.sys.tr("Экран блокировки: что на нём видно и когда он появляется."),
          keys: "lock screen blur idle блокировка экран размытие" },
        { id: "display", title: "Display",        g: 0xF0379, page: "SetDisplay.qml",
          sub: view.sys.tr("Разрешение, частота и масштаб подключённых экранов."),
          keys: "display monitor resolution refresh scale layout placement detect island "
                + "экран монитор разрешение герцовка раскладка расположение остров" },
        { id: "input",   title: "Mouse",           g: 0xF037D, page: "SetInput.qml",
          sub: view.sys.tr("Скорость указателя и разгон."),
          keys: "mouse pointer cursor sensitivity speed accel acceleration raw input flat "
                + "мышь указатель курсор скорость сенса чувствительность разгон прямой ввод" },
        { id: "system",  title: "System",         g: 0xF0493, page: "SetSystem.qml",
          sub: view.sys.tr("Из чего собрана машина и чем она сейчас занята."),
          keys: "about system cpu ram temperature система озу температура процессы" }
    ]

    readonly property var section: sections[Math.max(0, Math.min(sections.length - 1, tab))]

    // Раздел могли попросить по имени — например уведомление об обновлении
    // ведёт прямо в System. Имя ищем здесь: список разделов живёт тут же, и
    // никому снаружи не нужно знать, какой у раздела номер.
    function goToSection(id) {
        if (!id) return;
        for (var i = 0; i < view.sections.length; i++) {
            if (view.sections[i].id === id) { view.go(i); break; }
        }
        // просьбу выполнили — иначе повторное открытие настроек снова
        // уводило бы в тот же раздел
        view.sys.settingsSection = "";
    }
    Component.onCompleted: view.goToSection(view.sys.settingsSection)
    Connections {
        target: view.sys
        function onSettingsSectionChanged() { view.goToSection(view.sys.settingsSection); }
    }

    // ------------------------------------------------------------- история
    // Стрелки над разделом ходят по уже открытым, как в браузере: список
    // разделов длинный, и возврат к предыдущему руками сбивает с мысли.
    property var hist: [0]
    property int histAt: 0
    function go(i) {
        if (i === view.tab) return;
        var h = view.hist.slice(0, view.histAt + 1);
        h.push(i);
        view.hist = h;
        view.histAt = h.length - 1;
        view.tab = i;
    }
    function back()    { if (canBack)    { view.histAt--; view.tab = view.hist[view.histAt]; } }
    function forward() { if (canForward) { view.histAt++; view.tab = view.hist[view.histAt]; } }
    readonly property bool canBack:    histAt > 0
    readonly property bool canForward: histAt < hist.length - 1

    // ------------------------------------------------------------- поиск
    property string query: ""
    function matches(s) {
        if (view.query.length === 0) return true;
        var q = view.query.toLowerCase();
        return s.title.toLowerCase().indexOf(q) >= 0 || s.keys.toLowerCase().indexOf(q) >= 0;
    }

    // ========================================================== само окно
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ----------------------------------------------------- сайдбар
        ColumnLayout {
            // Ширина по самой длинной подписи, а не «на глаз»: список
            // разделов известен заранее, и лишний воздух справа от него
            // только отъедал место у самих настроек.
            readonly property real navW: {
                var m = 0;
                for (var i = 0; i < view.sections.length; i++)
                    m = Math.max(m, navMetric.advanceWidth(view.sections[i].title));
                // 7 отступ + 28 значок + 10 зазор + текст + 14 запас.
                // Метрики шрифта по семейству дают чуть меньше, чем меряет
                // сам Text (начертание подбирается позже), поэтому к тексту
                // добавлена десятая часть: без неё длинные названия резались
                // многоточием ровно там, где места на самом деле хватало.
                return Math.max(196, Math.min(300, Math.ceil(m * 1.25) + 64));
            }
            FontMetrics {
                id: navMetric
                font.family: view.sys.fontBody
                font.pixelSize: view.sys.fontSize - 1
            }

            // Вложенный в RowLayout слой по умолчанию растягивается сам —
            // без явного отказа ширина по тексту ничего не решала, и сайдбар
            // забирал всё свободное место.
            Layout.fillWidth: false
            Layout.preferredWidth: navW
            Layout.minimumWidth: navW
            Layout.maximumWidth: navW
            Layout.fillHeight: true
            spacing: 10

            // поиск по разделам
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 12
                color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b,
                               searchInput.activeFocus ? 0.12 : 0.07)
                Behavior on color { ColorAnimation { duration: view.sys.animFade } }

                Text {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 11
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(0xF0349)
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                }

                TextInput {
                    id: searchInput
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: view.sys.colFg
                    clip: true
                    selectByMouse: true
                    selectionColor: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4)
                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 2 }
                    onTextChanged: view.query = text
                    // Enter открывает первый подошедший раздел
                    onAccepted: {
                        for (var i = 0; i < view.sections.length; i++)
                            if (view.matches(view.sections[i])) { view.go(i); break; }
                    }
                    Keys.onEscapePressed: { text = ""; focus = false; }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: searchInput.text.length === 0
                        text: view.sys.tr("Поиск настроек")
                        color: view.sys.colMuted
                        font: searchInput.font
                    }
                }
            }

            // список разделов
            ListView {
                id: nav
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: view.sections
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: SetScroll { sys: view.sys }

                // то же колесо, что и у страницы: список разделов длиннее
                // окна, когда шрифт крупный
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                        var max = Math.max(0, nav.contentHeight - nav.height);
                        nav.contentY = Math.max(0, Math.min(max, nav.contentY - d));
                    }
                }

                delegate: Rectangle {
                    id: navItem
                    required property int index
                    required property var modelData
                    readonly property bool active: view.tab === navItem.index
                    readonly property bool shown: view.matches(navItem.modelData)

                    width: nav.width
                    height: shown ? 42 : 0
                    visible: shown
                    radius: 13
                    color: navItem.active
                           ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.16)
                           : (navMa.containsMouse
                              ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.07)
                              : "transparent")
                    border.width: 1
                    border.color: navItem.active
                                  ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.35)
                                  : "transparent"
                    Behavior on color { ColorAnimation { duration: view.sys.animFade } }
                    Behavior on border.color { ColorAnimation { duration: view.sys.animFade } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 7
                        anchors.rightMargin: 10
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 9
                            color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: String.fromCodePoint(navItem.modelData.g)
                                color: navItem.active ? view.sys.colOn : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1 }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: navItem.modelData.title
                            color: navItem.active ? view.sys.colFg : view.sys.colMuted
                            elide: Text.ElideRight
                            font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 1 }
                        }
                    }

                    MouseArea {
                        id: navMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.go(navItem.index)
                    }
                }
            }
        }

        // ----------------------------------------------------- раздел
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 18
            spacing: 12

            // стрелки истории
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [{ g: 0xF004D, fwd: false }, { g: 0xF0054, fwd: true }]
                    Rectangle {
                        id: navArrow
                        required property var modelData
                        readonly property bool armed: navArrow.modelData.fwd ? view.canForward : view.canBack

                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 28
                        radius: 9
                        opacity: navArrow.armed ? 1 : 0.35
                        color: arrowMa.containsMouse && navArrow.armed
                               ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12)
                               : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                        Behavior on color { ColorAnimation { duration: view.sys.animFade } }

                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(navArrow.modelData.g)
                            color: view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                        }

                        MouseArea {
                            id: arrowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: navArrow.armed
                            cursorShape: Qt.PointingHandCursor
                            onClicked: navArrow.modelData.fwd ? view.forward() : view.back()
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // шапка и карточки раздела в общей прокрутке
            Flickable {
                id: scroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: pageCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 3000
                ScrollBar.vertical: SetScroll { sys: view.sys }

                // Колесо крутим сами. Собственная обработка Flickable зависит
                // от того, кому достанется событие: остров ловит наведение
                // своим HoverHandler'ом и в части положений забирал колесо
                // себе — прокрутка работала только у верхней кромки.
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                        var max = Math.max(0, scroll.contentHeight - scroll.height);
                        scroll.contentY = Math.max(0, Math.min(max, scroll.contentY - d));
                    }
                }

                ColumnLayout {
                    id: pageCol
                    width: scroll.width - 12   // место под полосу прокрутки
                    spacing: 12

                    SetHeader {
                        sys: view.sys
                        glyph: String.fromCodePoint(view.section.g)
                        title: view.section.title
                        sub: view.section.sub
                    }

                    // Страницу поднимаем через setSource с готовым `sys`:
                    // при простом source страница успевает построиться с
                    // пустой ссылкой, и все её привязки к палитре падают.
                    Loader {
                        id: pageLoader
                        Layout.fillWidth: true

                        function reload() { setSource(view.section.page, { sys: view.sys }); }
                        Component.onCompleted: reload()

                        Connections {
                            target: view
                            function onTabChanged() { pageLoader.reload(); }
                        }
                    }

                    Item { Layout.preferredHeight: 8 }
                }
            }
        }
    }

    // раздел сменился — прокрутка начинается сверху, а не там, где кончился
    // предыдущий
    onTabChanged: scroll.contentY = 0
}
