import QtQuick
import QtQuick.Layouts

// Appearance. Тема задаёт палитру всей оболочки и ни от чего больше не
// зависит: обои меняются сами по себе, цвет — сам по себе. Тема «Default»
// оставлена как была, поэтому вручную выбранные цвет текста и акцент
// продолжают работать именно на ней.
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

    // ------------------------------------------------------------- тема
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Тема") }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: page.sys.themes

                Rectangle {
                    id: swatch
                    required property var modelData
                    readonly property bool active: page.sys.cfg.themeId === swatch.modelData.id

                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    radius: 14
                    color: swatch.modelData.bg
                    border.width: swatch.active ? 2 : 1
                    border.color: swatch.active
                                  ? swatch.modelData.on
                                  : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b,
                                            swatchMa.containsMouse ? 0.30 : 0.12)
                    Behavior on border.color { ColorAnimation { duration: page.sys.animFade } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 9

                        // три кружка: акцент, текст, тревожный цвет — по ним
                        // тема узнаётся быстрее, чем по названию
                        Repeater {
                            model: [swatch.modelData.on, swatch.modelData.fg, swatch.modelData.crit]
                            Rectangle {
                                required property var modelData
                                width: 14; height: 14; radius: 7
                                color: modelData
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 9
                        text: swatch.modelData.name
                        color: swatch.modelData.fg
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                    }

                    MouseArea {
                        id: swatchMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { page.sys.cfg.themeId = swatch.modelData.id; page.sys.saveCfg(); }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: page.sys.cfg.themeId === "default"
            text: page.sys.tr("На теме Default цвет текста и акцент берутся из настроек ниже; у остальных тем они свои.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        // Тумблер стоит здесь, рядом с выбором темы: карточки — часть облика,
        // а не отдельная служба.
        SetToggle {
            sys: page.sys
            label: page.sys.tr("Настольные виджеты")
            sub: page.sys.tr("Карточки на обоях: дата, погода и часы. Начертание берут у выбранной темы.")
            on: page.sys.cfg.featWidgets
            onToggled: v => { page.sys.cfg.featWidgets = v; page.sys.saveCfg(); }
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

        // Прозрачность терминала. Здесь, а не в отдельной вкладке: это одна
        // ручка, и стоит она рядом с прочим внешним видом.
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

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Приглушённый текст")
            from: 0.2; to: 1.0; step: 0.05
            decimals: 2
            value: page.sys.cfg.mutedAlpha
            onMoved: v => { page.sys.cfg.mutedAlpha = v; page.sys.saveCfg(); }
        }
    }

    // ------------------------------------------------------------- шрифты
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Type") }

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

    // ------------------------------------------------------------- геометрия
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Shape & depth") }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Spacing unit")
            from: 4; to: 16; step: 1
            value: page.sys.cfg.spacingUnit
            suffix: "px"
            onMoved: v => { page.sys.cfg.spacingUnit = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Small radius")
            from: 0; to: 24; step: 1
            value: page.sys.cfg.smallRadius
            suffix: "px"
            onMoved: v => { page.sys.cfg.smallRadius = v; page.sys.saveCfg(); }
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
