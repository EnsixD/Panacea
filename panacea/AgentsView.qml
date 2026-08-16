import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Агенты: тарифы и загрузка лимитов установленных ИИ-агентов.
//
// Данные приезжают из scripts/agents.sh — он и решает, кто установлен и что
// про него известно. Вид ничего не знает про формат чужих конфигов и рисует
// то, что дали.
//
// Полоски здесь НЕ ползунки: у них нет ни MouseArea, ни обработчика колеса.
// Это индикаторы, и тащить их некуда — лимит задаётся тарифом, а не окном.
Item {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    property var  agents: []
    property real serverNow: 0
    property bool loaded: false

    // Часы для обратного отсчёта. Отдельно от опроса скрипта: до сброса лимита
    // бывают часы, и гонять из-за подписи «через 2 ч 14 мин» целый процесс раз
    // в секунду незачем. Тик раз в 30 с — подпись в минутах точнее не станет.
    property real clockNow: Date.now()
    Timer {
        interval: 30000; repeat: true; running: true
        onTriggered: view.clockNow = Date.now()
    }

    Process {
        id: pAgents
        command: ["sh", view.sys.scriptDir + "/agents.sh"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text);
                    view.agents = d.agents || [];
                    view.serverNow = d.now || Date.now();
                } catch (e) {
                    view.agents = [];
                }
                view.loaded = true;
                view.clockNow = Date.now();
            }
        }
    }

    function refresh() { pAgents.running = false; pAgents.running = true; }

    // Опрос пореже, чем кажется нужным: сам файл с нагрузкой обновляет агент,
    // когда работает, а не оболочка. Чаще спрашивать — значит чаще перечитывать
    // то же самое.
    Timer {
        interval: 20000; repeat: true; running: true
        onTriggered: view.refresh()
    }

    // Открыли окно — перечитали. Одного создания вида мало: пока страница не
    // сброшена на главную, повторное открытие переиспользует тот же вид, и
    // цифры остались бы теми, что приехали в прошлый раз. Счётчик в оболочке
    // растёт на каждое открытие, и этого достаточно.
    Connections {
        target: view.sys
        function onAgentsEpochChanged() { view.refresh(); }
    }

    // Смена аккаунта или свежие цифры — это правка одного файла, и ждать до
    // следующего тика незачем: перечитываем сразу, как он изменился.
    FileView {
        path: Quickshell.env("HOME") + "/.claude.json"
        watchChanges: true
        printErrors: false
        onFileChanged: view.refresh()
    }

    // ------------------------------------------------------------- подписи
    // Ключ приходит устойчивый (kind), человеческое имя подставляем здесь:
    // иначе смена языка интерфейса до этого окна бы не дошла.
    function limitLabel(kind) {
        switch (String(kind)) {
        case "session":       return view.sys.tr("5 часов");
        case "weekly_all":    return view.sys.tr("Неделя");
        case "weekly_opus":   return view.sys.tr("Opus, неделя");
        case "weekly_sonnet": return view.sys.tr("Sonnet, неделя");
        }
        return String(kind).replace(/_/g, " ");
    }

    // «через 2 ч 14 мин». Окно, которое давно должно было обновиться, так и
    // говорим: данные лежат в кэше агента, и пока он не запускался, там висит
    // старое. Соврать «0%» было бы хуже — это выглядело бы как факт.
    function untilText(ms) {
        if (!ms || ms <= 0) return "";
        var left = ms - view.clockNow;
        if (left <= 0) return view.sys.tr("окно уже обновилось");
        var mins = Math.floor(left / 60000);
        var h = Math.floor(mins / 60), m = mins % 60;
        var pre = view.sys.tr("обновится через") + " ";
        if (h >= 24) return pre + Math.floor(h / 24) + " " + view.sys.tr("д") + " " + (h % 24) + " " + view.sys.tr("ч");
        if (h > 0)   return pre + h + " " + view.sys.tr("ч") + " " + m + " " + view.sys.tr("мин");
        return pre + Math.max(1, m) + " " + view.sys.tr("мин");
    }

    function agoText(ms) {
        if (!ms || ms <= 0) return "";
        var mins = Math.floor((view.clockNow - ms) / 60000);
        if (mins < 1)  return view.sys.tr("только что");
        if (mins < 60) return mins + " " + view.sys.tr("мин назад");
        var h = Math.floor(mins / 60);
        if (h < 24) return h + " " + view.sys.tr("ч назад");
        return Math.floor(h / 24) + " " + view.sys.tr("д назад");
    }

    // Цвет по нагрузке, а не по названию лимита: важно, сколько осталось.
    function barColor(pct, severity) {
        if (String(severity) === "critical" || pct >= 90) return view.sys.colCrit;
        if (pct >= 70) return view.sys.colWarn;
        return view.sys.colOn;
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 14

        // -------------------------------------------------------- заголовок
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Glyph {
                glyph: String.fromCodePoint(0xF1719)   // md-robot_outline
                color: view.sys.colFg
                fontFam: view.sys.fontFam
                size: 19
            }
            Text {
                text: view.sys.tr("Агенты")
                color: view.sys.colFg
                font { family: view.sys.fontDisplay; pixelSize: view.sys.fontSize + 1; bold: true }
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: view.loaded && view.agents.length > 0
                text: view.agents.length
                color: view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
            }
        }

        // ------------------------------------------------------- карточки
        Repeater {
            model: view.agents

            Rectangle {
                id: card
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: body.implicitHeight + 26
                radius: 14
                color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.05)
                border.width: 1
                border.color: view.sys.colLine

                ColumnLayout {
                    id: body
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 14; rightMargin: 14
                    }
                    spacing: 10

                    // имя агента, версия и тариф
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: card.modelData.name || ""
                            color: view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2; bold: true }
                        }
                        Text {
                            visible: String(card.modelData.version || "").length > 0
                            text: card.modelData.version || ""
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5 }
                        }
                        Item { Layout.fillWidth: true }

                        // Тариф плашкой: это не подпись к чему-то, а сам факт,
                        // и его ищут глазами первым.
                        Rectangle {
                            visible: String(card.modelData.plan || "").length > 0
                            implicitWidth: planText.implicitWidth + 18
                            implicitHeight: 22
                            radius: 11
                            color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.18)
                            Text {
                                id: planText
                                anchors.centerIn: parent
                                text: card.modelData.plan || ""
                                color: view.sys.colOn
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5; bold: true }
                            }
                        }
                    }

                    // ------------------------------------------- лимиты
                    Repeater {
                        model: card.modelData.limits || []

                        ColumnLayout {
                            id: lim
                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 5

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text {
                                    text: view.limitLabel(lim.modelData.kind)
                                    color: view.sys.colFg
                                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: Math.round(lim.modelData.percent) + "%"
                                    color: view.barColor(lim.modelData.percent, lim.modelData.severity)
                                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4; bold: true }
                                }
                            }

                            // Полоска. Ни MouseArea, ни WheelHandler: показывает,
                            // но не даёт себя тянуть.
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 7
                                radius: 4
                                color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.10)

                                Rectangle {
                                    height: parent.height
                                    radius: parent.radius
                                    width: parent.width * Math.max(0, Math.min(100, lim.modelData.percent)) / 100
                                    color: view.barColor(lim.modelData.percent, lim.modelData.severity)
                                    Behavior on width  { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutQuint } }
                                    Behavior on color  { ColorAnimation  { duration: view.sys.animFade } }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: view.untilText(lim.modelData.resetsAt)
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 6 }
                            }
                        }
                    }

                    // Лимитов нет — говорим, почему именно. «Агент их не
                    // отдаёт» и «данных ещё не приехало» выглядят одинаково, а
                    // значат противоположное: первое навсегда, второе пройдёт
                    // само. После смены аккаунта видно как раз второе, и
                    // сообщать про «не отдаёт» было бы прямой неправдой.
                    //
                    // Пустая полоска на нуле не годится ни в том, ни в другом
                    // случае: она читается как «ничего не израсходовано», а мы
                    // просто не знаем.
                    Text {
                        Layout.fillWidth: true
                        visible: (card.modelData.limits || []).length === 0
                        // Для Claude подсказка конкретная. Он записывает
                        // нагрузку в свой файл, только когда сам сходит за ней
                        // на сервер, а делает это редко и по своему
                        // расписанию: после смены аккаунта ключа может не быть
                        // часами, и перезапуск ничего не меняет. Команда
                        // /usage идёт за ней принудительно — это и есть способ
                        // получить цифры сейчас, а не ждать.
                        text: String(card.modelData.note) !== "nodata"
                              ? view.sys.tr("Лимиты этот агент наружу не отдаёт")
                              : String(card.modelData.id) === "claude"
                              ? view.sys.tr("Данных пока нет — выполните /usage в Claude Code")
                              : view.sys.tr("Данных пока нет — появятся, когда агент поработает")
                        color: view.sys.colMuted
                        wrapMode: Text.WordWrap
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5 }
                    }

                    // Когда цифры в последний раз обновлял сам агент. Важно:
                    // остров их не запрашивает, он читает то, что агент оставил
                    // у себя, — и без этой строки свежесть выглядела бы
                    // сегодняшней всегда.
                    Text {
                        Layout.fillWidth: true
                        visible: (card.modelData.limits || []).length > 0
                                 && String(view.agoText(card.modelData.fetchedAt)).length > 0
                        text: view.sys.tr("данные агента от") + " " + view.agoText(card.modelData.fetchedAt)
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 6 }
                    }
                }
            }
        }

        // ---------------------------------------------------------- пусто
        Text {
            Layout.fillWidth: true
            visible: view.loaded && view.agents.length === 0
            text: view.sys.tr("Ни одного агента не найдено")
            color: view.sys.colMuted
            horizontalAlignment: Text.AlignHCenter
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
        }
    }
}
