import QtQuick
import QtQuick.Layouts

// Appearance. Оформление в стиле Nothing OS: минималистичная монохромная
// палитра, фирменные точечные шрифты, виджеты рабочего стола и системные звуки.
ColumnLayout {
    id: page

    property var sys

    Layout.fillWidth: true
    spacing: 12

    // ------------------------------------------------------------- язык
    // Стоит первым: с языка начинают, а не заканчивают им.
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Язык") }

        SetSelect {
            sys: page.sys
            label: page.sys.tr("Язык системы")
            options: [
                { id: "en", text: "English" },
                { id: "ru", text: "Русский" }
            ]
            value: page.sys.cfg.lang
            onPicked: id => page.sys.setLang(id)
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.sysLangPending
                  ? page.sys.tr("Меняем язык системы…")
                  : (page.sys.sysLang !== page.sys.cfg.lang
                     ? page.sys.tr("Оболочка уже на новом языке. Приложения и меню читают язык при входе — они переключатся после перезахода.")
                     : page.sys.tr("Оболочка переключается сразу. Приложения и меню — после перезахода: язык они читают при входе."))
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }

    // ------------------------------------------------------------- виджеты
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Настольные виджеты") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Виджеты на рабочем столе")
            sub: page.sys.tr("Карточки Nothing OS на обоях: дата, часы, погода, системный монитор и шкала прогресса. Клик по карточкам переключает режимы.")
            on: page.sys.cfg.featWidgets
            onToggled: v => { page.sys.cfg.featWidgets = v; page.sys.saveCfg(); }
        }

        SetSelect {
            visible: page.sys.cfg.featWidgets
            sys: page.sys
            label: page.sys.tr("Стиль часов")
            options: [
                { id: "analog", text: page.sys.tr("Аналоговые Nothing") },
                { id: "digital", text: page.sys.tr("Цифровые точечные") }
            ]
            value: page.sys.cfg.widgetClockMode || "analog"
            onPicked: id => { page.sys.cfg.widgetClockMode = id; page.sys.saveCfg(); }
        }

        SetSelect {
            visible: page.sys.cfg.featWidgets
            sys: page.sys
            label: page.sys.tr("Информационный блок")
            options: [
                { id: "weather", text: page.sys.tr("Погода (ветер и влажность)") },
                { id: "system", text: page.sys.tr("Система (RAM и SSD)") }
            ]
            value: page.sys.cfg.widgetRightMode || "weather"
            onPicked: id => { page.sys.cfg.widgetRightMode = id; page.sys.saveCfg(); }
        }

        SetSelect {
            visible: page.sys.cfg.featWidgets
            sys: page.sys
            label: page.sys.tr("Шкала прогресса")
            options: [
                { id: "day", text: page.sys.tr("Прогресс дня (24 часа)") },
                { id: "year", text: page.sys.tr("Прогресс года (365 дней)") }
            ]
            value: page.sys.cfg.widgetProgressMode || "day"
            onPicked: id => { page.sys.cfg.widgetProgressMode = id; page.sys.saveCfg(); }
        }

        Text {
            Layout.fillWidth: true
            visible: page.sys.cfg.featWidgets
                     && page.sys.cfg.weatherKey.length === 0
            text: page.sys.tr("Впишите ключ и город во вкладке Weather, иначе карточка погоды останется пустой.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }

    // ------------------------------------------------------------- оформление
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Оформление") }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Приглушённый текст")
            from: 0.2; to: 1.0; step: 0.05
            decimals: 2
            value: page.sys.cfg.mutedAlpha
            onMoved: v => { page.sys.cfg.mutedAlpha = v; page.sys.saveCfg(); }
        }

        // Прозрачность терминала
        SetSlider {
            sys: page.sys
            label: page.sys.tr("Прозрачность терминала")
            from: 0.5; to: 1.0; step: 0.01
            decimals: 2
            value: page.sys.cfg.termAlpha
            onMoved: v => {
                page.sys.cfg.termAlpha = v;
                page.sys.saveCfg();
                page.sys.applyTermAlpha();
            }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("1.00 — сплошной фон. Действует сразу; если нет — терминал держит свои настройки с прошлого входа, и его серверу нужен перезапуск.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item { Layout.fillWidth: true }

            SetButton {
                sys: page.sys
                text: page.sys.tr("Перезапустить терминал")
                onClicked: page.sys.restartTerminalServer()
            }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Открытые окна терминала при этом закроются: они работают от того же сервера.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }

    // ------------------------------------------------------------- шрифты
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Шрифты") }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Font size")
            from: 10; to: 24; step: 1
            value: page.sys.cfg.fontSize
            suffix: "px"
            onMoved: v => { page.sys.cfg.fontSize = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Icon size")
            from: 12; to: 28; step: 1
            value: page.sys.cfg.iconSize
            suffix: "px"
            onMoved: v => { page.sys.cfg.iconSize = v; page.sys.saveCfg(); }
        }

        SetPick {
            sys: page.sys
            label: page.sys.tr("Body font")
            options: page.sys.fontList
            value: page.sys.cfg.fontBody || page.sys.cfg.fontFam
            onPicked: id => { page.sys.cfg.fontBody = id; page.sys.saveCfg(); }
        }

        SetPick {
            sys: page.sys
            label: page.sys.tr("Display font")
            options: page.sys.fontList
            value: page.sys.cfg.fontDisplay || page.sys.cfg.fontFam
            onPicked: id => { page.sys.cfg.fontDisplay = id; page.sys.saveCfg(); }
        }

        // Значковый шрифт отдельно: подписи можно поставить любые, но иконки
        // рисует только Nerd Font, и менять его вместе с текстовым нельзя.
        SetPick {
            sys: page.sys
            label: page.sys.tr("Шрифт значков")
            options: page.sys.fontList
            value: page.sys.cfg.fontFam
            onPicked: id => { page.sys.cfg.fontFam = id; page.sys.saveCfg(); }
        }
    }

    // ------------------------------------------------------------- звуки
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Звуки") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Звуковые эффекты системы")
            sub: page.sys.tr("Зарядка, подключение Bluetooth, скриншоты, голосовой ввод")
            on: page.sys.cfg.uiSounds !== false
            onToggled: value => {
                page.sys.cfg.uiSounds = value;
                page.sys.saveCfg();
                if (value) page.sys.playSound("connect");
            }
        }

        // Кнопки предпрослушивания звуков
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8
            visible: page.sys.cfg.uiSounds !== false

            Repeater {
                model: [
                    { id: "charge",      label: page.sys.tr("Зарядка"),     icon: "󰂄" },
                    { id: "connect",     label: "Bluetooth",               icon: "󰂯" },
                    { id: "disconnect",  label: page.sys.tr("Отключение"),  icon: "󰂲" },
                    { id: "screenshot",  label: page.sys.tr("Скриншот"),    icon: "󰄀" },
                    { id: "voice_start", label: page.sys.tr("Голос"),       icon: "󰍬" }
                ]

                Rectangle {
                    id: sndBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 8
                    color: sndMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: sndMa.containsMouse ? page.sys.colOn : page.sys.colLine
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: modelData.icon
                            color: sndMa.containsMouse ? page.sys.colOn : page.sys.colMuted
                            font { family: page.sys.fontFam; pixelSize: 13 }
                        }
                        Text {
                            text: modelData.label
                            color: sndMa.containsMouse ? page.sys.colFg : page.sys.colMuted
                            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: sndMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.sys.playSound(modelData.id)
                    }
                }
            }
        }
    }
}
