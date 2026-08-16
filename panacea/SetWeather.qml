import QtQuick
import QtQuick.Layouts

// Weather. Данные берутся с OpenWeatherMap, а ключ к нему у каждого свой:
// он бесплатный, но выдаётся на почту и привязан к учётной записи, поэтому
// вписать сюда общий на всех нельзя.
//
// Страница нужна только настольным виджетам — больше погоду в оболочке
// негде показать, — и об этом сказано прямо, чтобы не искать, где же она
// появится после заполнения полей.
ColumnLayout {
    id: page

    property var sys

    // Причина отказа словами. Коды приходят из scripts/weather.sh; здесь их
    // единственное место перевода в человеческую речь.
    function errText(e) {
        return e === "no-key"        ? page.sys.tr("Ключ не вписан")
             : e === "no-city"       ? page.sys.tr("Город не вписан")
             : e === "bad-key"       ? page.sys.tr("Ключ не подошёл — проверьте, что скопирован целиком")
             : e === "no-such-city"  ? page.sys.tr("Такого города сервис не знает")
             : e === "rate-limit"    ? page.sys.tr("Слишком часто спрашиваем — ключ на пределе обращений")
             : e === "network"       ? page.sys.tr("Не дозвонились до сервиса")
             : e === "no-curl"       ? page.sys.tr("Нет curl")
             : e === "no-jq"         ? page.sys.tr("Нет jq")
             : e === "bad-answer"    ? page.sys.tr("Ответ сервиса не разобрать")
             : page.sys.tr("Сервис ответил отказом") + " (" + e + ")";
    }

    Layout.fillWidth: true
    spacing: 12

    // ------------------------------------------------------------- ключ
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Ключ OpenWeatherMap") }

        // Ключ прячется точками. Он открывает чужой платный счёт, а окно
        // настроек открывают и при посторонних, и с включённой демонстрацией
        // экрана — незачем показывать его каждый раз, когда сюда заглянули
        // поменять город.
        //
        // Кнопка-глаз рядом обязательна: вслепую вписанные 32 знака нечем
        // проверить, а «ключ не подошёл» одинаково выглядит и при опечатке,
        // и при неактивированном ключе.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 10
            color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.07)

            property bool shown: false

            TextInput {
                id: keyInput
                anchors.fill: parent
                anchors.leftMargin: 12
                // место под кнопку справа
                anchors.rightMargin: 38
                verticalAlignment: Text.AlignVCenter
                color: page.sys.colFg
                clip: true
                selectByMouse: true
                text: page.sys.cfg.weatherKey
                echoMode: parent.shown ? TextInput.Normal : TextInput.Password
                // Точки, а не звёздочки: звёздочка в моноширинном шрифте
                // сидит выше середины строки, и ряд из них смотрится
                // надстрочным.
                passwordCharacter: "•"
                // Показываем сразу целиком, без пробегающего последнего
                // знака: ключ вставляют из буфера, а не набирают руками.
                passwordMaskDelay: 0
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                onEditingFinished: {
                    page.sys.cfg.weatherKey = text.trim();
                    page.sys.saveCfg();
                    page.sys.refreshWeather();
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: keyInput.text.length === 0
                    text: page.sys.tr("Строка из 32 знаков со страницы API keys")
                    color: page.sys.colMuted
                    elide: Text.ElideRight
                    font: keyInput.font
                }
            }

            Text {
                id: eye
                anchors.right: parent.right
                anchors.rightMargin: 11
                anchors.verticalCenter: parent.verticalCenter
                text: String.fromCodePoint(parent.shown ? 0xF0209 : 0xF0208)
                color: eyeMa.containsMouse ? page.sys.colFg : page.sys.colMuted
                font { family: page.sys.fontFam; pixelSize: page.sys.iconSize - 2 }
                Behavior on color { ColorAnimation { duration: 140 } }

                MouseArea {
                    id: eyeMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: eye.parent.shown = !eye.parent.shown
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Заводится на openweathermap.org — бесплатно. Новый ключ начинает отвечать не сразу, обычно через час-другой.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        // Сказано прямо: ключ лежит в settings.json как есть. Человек вправе
        // знать это до того, как впишет его, а не выяснить потом.
        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Хранится в settings.json открытым текстом.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }

    // ------------------------------------------------------------ город
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Город") }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 10
            color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.07)

            TextInput {
                id: cityInput
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: Text.AlignVCenter
                color: page.sys.colFg
                clip: true
                selectByMouse: true
                text: page.sys.cfg.weatherCity
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                onEditingFinished: {
                    page.sys.cfg.weatherCity = text.trim();
                    page.sys.saveCfg();
                    page.sys.refreshWeather();
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: cityInput.text.length === 0
                    text: page.sys.tr("Название или индекс: Moscow,RU или 101000")
                    color: page.sys.colMuted
                    elide: Text.ElideRight
                    font: cityInput.font
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Годится и почтовый индекс — сплошные цифры оболочка отличает от названия сама и без страны считает российскими. Одинаковых названий на свете много: если нашёлся не тот город, допишите через запятую страну — Moscow,RU. По названию сервис ищет надёжнее, чем по индексу.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        // Отдельно от настольных виджетов: остров виден всегда, а стол
        // закрыт окнами, и включают их не за одно и то же.
        SetToggle {
            sys: page.sys
            label: page.sys.tr("Погода в острове")
            sub: page.sys.tr("Значок и градусы в свёрнутом острове, рядом с рабочими столами.")
            on: page.sys.cfg.weatherOnIsland
            onToggled: v => {
                page.sys.cfg.weatherOnIsland = v;
                page.sys.saveCfg();
                if (v) page.sys.refreshWeather();
            }
        }

        SetSelect {
            sys: page.sys
            label: page.sys.tr("Шкала")
            options: [
                { id: "metric",   text: page.sys.tr("Цельсий") },
                { id: "imperial", text: page.sys.tr("Фаренгейт") }
            ]
            value: page.sys.cfg.weatherUnits
            onPicked: id => {
                page.sys.cfg.weatherUnits = id;
                page.sys.saveCfg();
                page.sys.refreshWeather();
            }
        }
    }

    // ---------------------------------------------------------- проверка
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Сейчас") }

        Text {
            Layout.fillWidth: true
            text: page.sys.weatherBusy
                  ? page.sys.tr("Спрашиваем…")
                  : page.sys.weatherErr.length
                    ? page.errText(page.sys.weatherErr)
                    : page.sys.weatherReady
                      ? page.sys.weatherPlace + " · " + page.sys.weatherTemp + "°"
                        + page.sys.weatherUnitLetter + " · " + page.sys.weatherDesc
                      : page.sys.tr("Ещё не спрашивали")
            color: page.sys.weatherErr.length ? page.sys.colCrit : page.sys.colFg
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
        }

        Text {
            Layout.fillWidth: true
            visible: page.sys.weatherReady
            text: page.sys.tr("Влажность") + " " + page.sys.weatherHumidity + "% · "
                  + page.sys.tr("Ветер") + " " + page.sys.weatherWind + " "
                  + page.sys.weatherWindUnit + " · "
                  + page.sys.tr("Ощущается как") + " " + page.sys.weatherFeels + "°"
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
                text: page.sys.tr("Обновить")
                primary: true
                enabled: !page.sys.weatherBusy
                onClicked: page.sys.refreshWeather()
            }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Сама оболочка спрашивает погоду раз в четверть часа. Показывается она в настольных виджетах — включаются во вкладке Appearance.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }
}
