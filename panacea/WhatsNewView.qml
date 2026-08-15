import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

// Экран «что нового». Показывается один раз — сразу после того, как оболочка
// перезапустилась на свежей версии, — и закрывается кнопкой. Список изменений
// кладёт update.sh в ~/.config/panacea/.whatsnew; закрытие стирает файл, и
// второй раз экран не появится.
Item {
    id: view

    property var sys
    // первая строка файла — версия, остальные — заголовки коммитов
    property var lines: []
    readonly property string version: view.lines.length ? String(view.lines[0]).substring(0, 7) : ""
    readonly property var changes: view.lines.slice(1)

    // Сколько строк поместится, чтобы окно осталось окном, а не полосой во
    // весь экран: считаем от его высоты и от того, каким шрифтом писать.
    readonly property int maxRows: Math.max(4, Math.min(14,
        Math.floor((view.height - 380) / (view.sys.fontSize + 9))))
    readonly property int fontPx: view.changes.length > 9 ? view.sys.fontSize - 3
                                                          : view.sys.fontSize - 2
    readonly property var shown: view.changes.slice(0, view.maxRows)
    readonly property int hidden: Math.max(0, view.changes.length - view.maxRows)

    // ------------------------------------------------------------ переводы
    // История репозитория ведётся по-английски, а экран должен говорить на
    // языке системы. Поэтому здесь лежат заголовки коммитов и их перевод:
    // ключ — ровно та строка, что уходит в .whatsnew (первая строка
    // сообщения), значение — как её прочитает человек.
    //
    // Это работает и для коммитов, о которых экран рассказывает впервые:
    // update.sh пишет .whatsnew уже после того, как install.sh положил новую
    // версию оболочки, так что словарь приезжает вместе с изменениями,
    // которые он описывает.
    //
    // ВАЖНО: новый коммит — новая строка сюда. Без неё заголовок покажется
    // по-английски: не сломается, но выпадет из языка интерфейса.
    readonly property var dictRu: ({
        "screenshot: freeze the screen before selecting a region":
            "Скриншот: экран замирает на время выделения — снять можно и то, что закрывается от движения мыши",
        "install: make the shell the default handler for files it can open":
            "Установщик: оболочка становится обработчиком по умолчанию для того, что умеет открывать",
        "files: open-with actually opens, and stops filling the whole panel":
            "Проводник: «чем открыть» действительно открывает, список стал уже и слушается стрелок",
        "agents: follow the account, and refresh whenever the panel opens":
            "Агенты: следят за аккаунтом и перечитывают статистику при каждом открытии",
        "i18n: russian titles for the newest changes":
            "Перевод: русские заголовки для свежих изменений",
        "agents: say how to make the numbers appear, not just that they are missing":
            "Агенты: сказано, как получить цифры, а не только что их нет",
        "settings: read the update output as it arrives, not when it ends":
            "Настройки: ход обновления виден сразу, а не после его конца",
        "install: fonts for emoji and the scripts Noto covers":
            "Установщик: шрифты для эмодзи и письменностей, которые закрывает Noto",
        "launcher: keep the reboot alive after the launcher closes":
            "Лаунчер: перезагрузка в другую систему больше не срывается при закрытии окна",
        "settings: show the update check spinning and the download progressing":
            "Настройки: видно, что проверка обновления идёт, и как оно скачивается",
        "files: no menu when a drop changes nothing, and ask before overwriting":
            "Проводник: меню не появляется, если файл отпустили там же, а совпавшие имена теперь спрашивают",
        "files: list what is inside gvfs, not the gvfs mount itself":
            "Проводник: в съёмных больше не висит пустая запись gvfs",
        "files: a grid view beside the list, and no scrolling by drag":
            "Проводник: вид сеткой рядом со списком, и список больше не уезжает при перетаскивании",
        "launcher: restart straight into another installed system":
            "Лаунчер: перезагрузка сразу в другую установленную систему",
        "agents: plans and limits for every installed AI agent":
            "Агенты: тарифы и лимиты установленных ИИ-агентов",
        "install: ask about the AUR helper up front, mask rival notifiers":
            "Установщик: спрашивает про помощник AUR заранее и убирает чужой демон уведомлений",
        "terminals: keep foot, drop kitty and ghostty":
            "Терминалы: остался один foot, kitty и ghostty убраны",
        "settings: drop the Plugins tab and the task pad":
            "Настройки: убран раздел Plugins вместе с блокнотом задач",
        "install: check where GRUB actually reads its config from":
            "Установщик: проверяет, откуда GRUB на самом деле читает конфиг",
        "fish: hide dotfiles unless -a asks for them":
            "Терминал: скрытые файлы показываются только по -a",
        "monitors: put the saved screen mode into the compositor config":
            "Экраны: сохранённый режим прописывается в конфиг компоновщика",
        "install: start the shell with the threaded render loop after installing":
            "Установщик: оболочка запускается с потоковым циклом отрисовки",
        "island: stop restarting the height animation while the page settles":
            "Остров: анимация высоты не дёргается, пока страница устаканивается",
        "controls: sliders land on exact values instead of fighting the hardware":
            "Быстрые настройки: ползунки встают на точные значения",
        "display: write the vibrance shader atomically and wait for the slider to settle":
            "Экран: шейдер насыщенности пишется целиком, без баннера с ошибкой",
        "grub: name the theme fonts the way they are stored inside the .pf2":
            "GRUB: имена шрифтов темы совпадают с тем, как они лежат в .pf2",
        "i18n: english strings for the new settings":
            "Перевод: английские строки для новых настроек",
        "install: build an AUR helper, add missing deps, offer fish as the login shell":
            "Установщик: собирает помощник AUR, ставит недостающее и предлагает fish оболочкой входа",
        "cursor: software cursors on NVIDIA, and a black minimal theme":
            "Курсор: программные курсоры на NVIDIA и чёрная минималистичная тема",
        "clock: 24-hour format everywhere, not just in the shell":
            "Часы: 24-часовой формат везде, а не только в оболочке",
        "fish: show dotfiles, add c/upd/ins, and stop fastfetch on startup":
            "Терминал: скрытые файлы, алиасы c/upd/ins и fastfetch больше не лезет при запуске",
        "files: fill the window and show dotfiles":
            "Проводник: список занимает всё окно и показывает скрытые файлы",
        "controls: hide the battery and power profiles on a desktop machine":
            "Быстрые настройки: на стационарной машине нет батареи и режимов питания",
        "controls: volume and brightness share one row":
            "Быстрые настройки: громкость и яркость встали в одну строку",
        "controls: show the wired network instead of Wi-Fi when a cable is in":
            "Быстрые настройки: при подключённом кабеле видно проводную сеть, а не Wi-Fi",
        "settings: language switch for the shell and the system":
            "Настройки: переключение языка оболочки и системы",
        "settings: pointer speed and raw input":
            "Настройки: скорость указателя и прямой ввод",
        "display: digital vibrance through a compositor shader":
            "Экран: цифровая насыщенность через шейдер компоновщика",
        "brightness: one control for the laptop backlight and desktop monitors":
            "Яркость: одна настройка для подсветки ноутбука и внешних мониторов",
        "settings: new keys for hidden files, screen colour and the pointer":
            "Настройки: новые ключи для скрытых файлов, цвета экрана и указателя",
        "install: kernel headers, or the Nvidia module never gets built":
            "Установщик: заголовки ядра, без которых модуль Nvidia не собирается",
        "install: open modules for Turing and newer, vendors by PCI id":
            "Установщик: открытые модули Nvidia для Turing и новее, вендор по PCI-идентификатору",
        "hypr: bring back a fallback config for Hyprland without Lua":
            "Hyprland: возвращён запасной конфиг для версий без поддержки Lua",
        "system: read the GPU temperature where hwmon has none":
            "Система: температура видеокарты читается и там, где hwmon её не даёт",
        "island: no battery block on a machine without a battery":
            "Остров: на машине без батареи блок заряда не показывается",
        "install: count finished downloads, not created files":
            "Установщик: считает завершённые загрузки, а не созданные файлы",
        "install: drivers, dual boot, plain qs, and a reboot at the end":
            "Установщик: драйверы, дуалбут, запуск через qs и перезагрузка в конце",
        "hypr: launch the shell by absolute path, not through a tilde":
            "Hyprland: оболочка запускается по полному пути, а не через «~»",
        "install: show the wallpaper pack downloading":
            "Установщик: видно, как скачивается пак обоев",
        "plugins: a tab of its own, and a task pad for the desktop":
            "Плагины: своя вкладка и блокнот задач",
        "settings: the update notice opens System":
            "Настройки: уведомление об обновлении открывает раздел System",
        "todo: finish it the way the island behaves":
            "Задачи: капсула ведёт себя как остров — ширина, разворот, кромка",
        "todo: a second capsule at the edge, not a window on the desktop":
            "Задачи: вторая капсула у кромки вместо окна на рабочем столе",
        "update: name the packages that are no longer needed":
            "Обновление: называет пакеты, которые больше не нужны",
        "install: drop configs for programs that never run":
            "Установщик: убраны конфиги программ, которые не запускаются",
        "island: with auto-hide on, hovering shows the pill and a click opens it":
            "Остров: при автопрятании наведение показывает пилюлю, а раскрывает клик",
        "battery mode: keep the pill, drop the second set of panels":
            "Режим батареи: остаётся пилюля, второй набор панелей убран",
        "install: fix the dependency list, and name what an update still needs":
            "Установщик: список зависимостей исправлен, обновление называет недостающие пакеты",
        "wob: colour it from the palette and stop leaking readers":
            "wob: цвета из палитры, и он больше не плодит процессы",
        "settings: finish the move off the legacy panel":
            "Настройки: старая панель убрана, клавиши переехали на новую",
        "shell: one FocusGrabber instead of six copies of it":
            "Оболочка: фокус в полях ввода — один общий механизм вместо шести",
        "files: show copying in the island, and queue what waits":
            "Проводник: копирование видно в острове, операции встают в очередь",
        "scripts: check QML syntax without starting the shell":
            "Скрипты: проверка синтаксиса QML до запуска оболочки",
        "hypr: drop program entries nothing points at":
            "Hyprland: убраны записи о программах, которые никто не вызывает",
        "shell: move the dictionary out of the way":
            "Оболочка: словарь интерфейса вынесен в отдельный файл",
        "island: show any long job, not just copying":
            "Остров: показывает любую долгую работу, не только копирование",
        "hypr: delete the config Hyprland does not read":
            "Hyprland: удалён конфиг, который не читается",
        "settings: one SetButton for Apply and Reset":
            "Настройки: общая кнопка для «Применить» и «Сбросить»",
        "whatsnew: say what changed in the language of the interface":
            "Что нового: список изменений на языке интерфейса",
        "wallpaper: write hyprpaper's new config format":
            "Обои: новый формат конфигурации hyprpaper",
        "install: leave the shell alone while an update is running":
            "Установщик: не трогает оболочку, пока идёт обновление",
        "update: hand the job to the freshly cloned script":
            "Обновление: работу доводит свежескачанный скрипт",
        "update: keep housekeeping commits out of the changelog":
            "Обновление: служебные коммиты не попадают в список изменений",
        "island: don't expand just because auto-hide revealed it":
            "Остров: не разворачивается только оттого, что выехал из-под края",
        "power menu: one icon weight for the whole row":
            "Меню питания: одинаковая толщина значков в ряду"
    })

    // Плашка с готовой командой: перечислять пакеты словами бессмысленно,
    // всё равно набирать руками. По нажатию команда уходит в буфер.
    component DepsNotice: Rectangle {
        id: notice
        property string text: ""
        property string cmd: ""
        property bool shown: false
        property color tone: view.sys.colMuted

        Layout.fillWidth: true
        visible: notice.shown
        implicitHeight: noticeCol.implicitHeight + 24
        radius: 14
        color: Qt.rgba(notice.tone.r, notice.tone.g, notice.tone.b, 0.10)
        border.width: 1
        border.color: Qt.rgba(notice.tone.r, notice.tone.g, notice.tone.b, 0.35)

        ColumnLayout {
            id: noticeCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 5

            Text {
                Layout.fillWidth: true
                text: notice.text
                color: view.sys.colFg
                wrapMode: Text.WordWrap
                font { family: view.sys.fontBody; pixelSize: view.fontPx; bold: true }
            }

            Text {
                Layout.fillWidth: true
                text: notice.cmd
                color: view.sys.colMuted
                wrapMode: Text.WrapAnywhere
                font { family: view.sys.fontFam; pixelSize: view.fontPx - 1 }
            }

            Text {
                Layout.fillWidth: true
                text: noticeMa.containsMouse ? view.sys.tr("Нажмите, чтобы скопировать")
                                             : view.sys.tr("Скопировать команду")
                color: view.sys.colOn
                font { family: view.sys.fontBody; pixelSize: view.fontPx - 2 }
            }
        }

        MouseArea {
            id: noticeMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.sys.copyText(notice.cmd)
        }
    }

    function changeText(subject) {
        if (view.sys.isEn) return subject;
        var t = view.dictRu[subject];
        return t !== undefined ? t : subject;
    }

    anchors.fill: parent

    // клик мимо карточки не закрывает: человек должен увидеть, что изменилось,
    // и закрыть это осознанно
    MouseArea { anchors.fill: parent }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(620, parent.width - 80)
        // высота строго по содержимому: списку тесно быть не должно
        height: Math.min(body.implicitHeight + 56, parent.height - 60)
        radius: 26
        color: view.sys.colBg
        border.width: 1
        border.color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12)

        // выезжает снизу и проявляется: тот же почерк, что у остальных окон
        opacity: 0
        transform: Translate { id: rise; y: 24 }
        Component.onCompleted: { card.opacity = 1; rise.y = 0; }
        Behavior on opacity { NumberAnimation { duration: view.sys.animMs } }

        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: 28
            spacing: 16

            // ------------------------------------------------- шапка
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Image {
                    Layout.alignment: Qt.AlignHCenter
                    source: Quickshell.env("HOME") + "/.config/panacea/assets/logo-128.png"
                    sourceSize.width: 72
                    sourceSize.height: 72
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: view.sys.tr("Panacea обновлена")
                    color: view.sys.colFg
                    font { family: view.sys.fontDisplay; pixelSize: view.sys.fontSize + 8 }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    visible: view.version.length > 0
                    text: view.sys.tr("Сборка") + " " + view.version
                    color: view.sys.colMuted
                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 3 }
                }
            }

            // ------------------------------------------------- изменения
            // Без прокрутки: окно растёт под список целиком. Прокрутка здесь
            // означала бы, что часть изменений человек не увидит, — а ради
            // них экран и показывают. Длинный список ужимается шрифтом, а
            // совсем длинный сворачивается в хвост «и ещё N».
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: changeCol.implicitHeight + 28
                radius: 18
                color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.045)

                ColumnLayout {
                    id: changeCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 7

                    Repeater {
                        model: view.shown

                        RowLayout {
                            required property string modelData
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 6
                                width: 5; height: 5; radius: 3
                                color: view.sys.colOn
                            }
                            Text {
                                Layout.fillWidth: true
                                text: view.changeText(modelData)
                                color: view.sys.colFg
                                wrapMode: Text.WordWrap
                                font { family: view.sys.fontBody; pixelSize: view.fontPx }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        visible: view.hidden > 0
                        text: view.sys.tr("и ещё") + " " + view.hidden
                              + (view.sys.cfg.lang === "en" ? " more" : "")
                        color: view.sys.colMuted
                        font { family: view.sys.fontBody; pixelSize: view.fontPx - 1 }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: view.changes.length === 0
                        horizontalAlignment: Text.AlignHCenter
                        text: view.sys.tr("Список изменений недоступен")
                        color: view.sys.colMuted
                        font { family: view.sys.fontBody; pixelSize: view.fontPx }
                    }
                }
            }

            // ------------------------------------------- пакеты системы
            // Обновление ставит только конфиги: пакеты — дело человека.
            // Молчать нельзя ни в ту, ни в другую сторону — иначе часть
            // оболочки не работает без объяснения, а ненужное остаётся
            // висеть в системе навсегда.
            DepsNotice {
                text: view.sys.tr("Не хватает пакетов")
                cmd: "sudo pacman -S --needed " + view.sys.missingDeps
                shown: view.sys.missingDeps.length > 0
                tone: view.sys.colCrit
            }

            DepsNotice {
                text: view.sys.tr("Больше не нужны")
                cmd: "sudo pacman -Rns " + view.sys.obsoleteDeps
                shown: view.sys.obsoleteDeps.length > 0
                tone: view.sys.colMuted
            }

            // ------------------------------------------------- кнопка
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 14
                color: okMa.containsMouse
                       ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.36)
                       : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.24)
                border.width: 1
                border.color: view.sys.colOn
                Behavior on color { ColorAnimation { duration: view.sys.animFade } }

                Text {
                    anchors.centerIn: parent
                    text: view.sys.tr("Хорошо")
                    color: view.sys.colFg
                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize; bold: true }
                }
                MouseArea {
                    id: okMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.dismissWhatsNew()
                }
            }
        }
    }

    focus: true
    Keys.onEscapePressed: view.sys.dismissWhatsNew()
    Keys.onReturnPressed: view.sys.dismissWhatsNew()
    Component.onCompleted: forceActiveFocus()
}
