import QtQuick
import QtQuick.Layouts

// Макет проводника для настроек. Только дизайн: та же шапка, те же закладки
// слева и те же строки списка, что в FilesView, но с придуманным содержимым и
// без единого обработчика.
//
// Размер задан в «настоящих» точках (designW × designH), а на месте макет
// просто масштабируется целиком — поэтому пропорции и отступы совпадают с
// живым проводником, а не подгоняются на глаз.
Item {
    id: mock
    property var sys
    property color accent: "#3b82f6"
    property color fg: "#ffffff"
    property string dirName: ""     // пусто — берём «Домашняя» из словаря
    property string dirPath: "/home/ensi"
    // узкий вид — для двух проводников рядом: закладки прячутся, как в окне
    property bool compact: false

    readonly property color muted: Qt.rgba(mock.fg.r, mock.fg.g, mock.fg.b, 0.45)
    readonly property color line: Qt.rgba(1, 1, 1, 0.10)
    readonly property string fam: mock.sys ? mock.sys.fontFam : "monospace"
    // Подписи макета живут на языке оболочки: жёсткий русский текст выглядел
    // ошибкой на английском интерфейсе.
    function t(k) { return mock.sys ? mock.sys.tr(k) : k; }

    // ---------------------------------------------------------------- шапка
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // «наверх»
            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 13
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: mock.line
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(0xF0143)
                    color: mock.fg
                    font { family: mock.fam; pixelSize: 15 }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: mock.dirName.length ? mock.dirName : mock.t("Домашняя")
                    color: mock.fg
                    font { family: mock.fam; pixelSize: 20; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    text: mock.dirPath
                    color: mock.muted
                    elide: Text.ElideMiddle
                    font { family: mock.fam; pixelSize: 12 }
                }
            }

            // строка фильтра
            Rectangle {
                Layout.preferredWidth: mock.compact ? 170 : 260
                Layout.preferredHeight: 38
                radius: 19
                color: Qt.rgba(1, 1, 1, 0.06)
                border.color: mock.line
                border.width: 1
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 11
                    anchors.rightMargin: 11
                    spacing: 7
                    Text {
                        text: String.fromCodePoint(0xF0349)
                        color: mock.muted
                        font { family: mock.fam; pixelSize: 13 }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: mock.t("Просто печатайте")
                        color: Qt.rgba(1, 1, 1, 0.30)
                        elide: Text.ElideRight
                        font { family: mock.fam; pixelSize: 14 }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: mock.line
        }

        // ------------------------------------------- закладки + список
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            ColumnLayout {
                Layout.preferredWidth: 190
                Layout.maximumWidth: 190
                Layout.alignment: Qt.AlignTop
                spacing: 3
                visible: !mock.compact

                Repeater {
                    model: [
                        { g: 0xF02DC, t: mock.t("Домашняя"),  on: true },
                        { g: 0xF0179, t: mock.t("Загрузки"),  on: false },
                        { g: 0xF0219, t: mock.t("Документы"), on: false },
                        { g: 0xF021F, t: mock.t("Картинки"),  on: false },
                        { g: 0xF0388, t: mock.t("Музыка"),    on: false },
                        { g: 0xF022B, t: mock.t("Видео"),     on: false },
                        { g: 0xF0A79, t: mock.t("Корзина"),   on: false }
                    ]
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 12
                        color: modelData.on ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            spacing: 9
                            Text {
                                text: String.fromCodePoint(modelData.g)
                                color: modelData.on ? mock.accent : mock.muted
                                font { family: mock.fam; pixelSize: 16 }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.t
                                color: modelData.on ? mock.fg : mock.muted
                                elide: Text.ElideRight
                                font {
                                    family: mock.fam; pixelSize: 14
                                    bold: modelData.on
                                }
                            }
                        }
                    }
                }

                // раздел «Диски» — как в живом проводнике
                Text {
                    Layout.topMargin: 10
                    text: mock.t("Диски")
                    color: mock.muted
                    font {
                        family: mock.fam; pixelSize: 11; bold: true
                        capitalization: Font.AllUppercase; letterSpacing: 1
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.color: mock.line
                    border.width: 1
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: String.fromCodePoint(0xF02CA)
                                color: mock.muted
                                font { family: mock.fam; pixelSize: 14 }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: mock.t("Система")
                                color: mock.fg
                                font { family: mock.fam; pixelSize: 13 }
                            }
                            Text {
                                text: "412 " + mock.t("ГБ")
                                color: mock.muted
                                font { family: mock.fam; pixelSize: 11 }
                            }
                        }
                        // полоса занятого места
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 4
                            radius: 2
                            color: Qt.rgba(1, 1, 1, 0.10)
                            Rectangle {
                                width: parent.width * 0.62
                                height: parent.height
                                radius: 2
                                color: mock.accent
                            }
                        }
                    }
                }
            }

            // ------------------------------------------------ сам список
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                // сортировка
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 7
                    Repeater {
                        model: [
                            { t: mock.t("Имя"),    on: true },
                            { t: mock.t("Размер"), on: false },
                            { t: mock.t("Дата"),   on: false },
                            { t: mock.t("Тип"),    on: false }
                        ]
                        Rectangle {
                            required property var modelData
                            Layout.preferredWidth: sortLbl.implicitWidth + (modelData.on ? 30 : 18)
                            Layout.preferredHeight: 26
                            radius: 9
                            color: modelData.on
                                   ? Qt.rgba(mock.accent.r, mock.accent.g, mock.accent.b, 0.18)
                                   : Qt.rgba(1, 1, 1, 0.05)
                            border.color: modelData.on
                                          ? Qt.rgba(mock.accent.r, mock.accent.g,
                                                    mock.accent.b, 0.45)
                                          : mock.line
                            border.width: 1
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 5
                                Text {
                                    id: sortLbl
                                    text: modelData.t
                                    color: modelData.on ? mock.fg : mock.muted
                                    font { family: mock.fam; pixelSize: 12; bold: modelData.on }
                                }
                                Text {
                                    visible: modelData.on
                                    text: String.fromCodePoint(0xF0143)
                                    color: mock.accent
                                    font { family: mock.fam; pixelSize: 10 }
                                }
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "14 " + mock.t("объектов")
                        color: Qt.rgba(1, 1, 1, 0.26)
                        font { family: mock.fam; pixelSize: 11 }
                    }
                }

                // строки: папки акцентом, файлы блёкло — как в живом списке
                Repeater {
                    model: [
                        { d: true,  n: "Panacea",        t: mock.t("вчера"),
                          s: "—", cur: true },
                        { d: true,  n: mock.t("Загрузки"), t: "12:04",
                          s: "—", cur: false },
                        { d: true,  n: "obsidian_vault", t: mock.t("9 авг"),
                          s: "—", cur: false },
                        { d: false, n: "demo.mp4",       t: mock.t("8 авг"),
                          s: "24,1 " + mock.t("МБ"), cur: false },
                        { d: false, n: "install.sh",     t: mock.t("8 авг"),
                          s: "11,2 " + mock.t("КБ"), cur: false },
                        { d: false, n: "README.md",      t: mock.t("7 авг"),
                          s: "6,4 " + mock.t("КБ"),  cur: false },
                        { d: false, n: "shell.qml",      t: mock.t("сегодня"),
                          s: "94 " + mock.t("КБ"),   cur: false }
                    ]
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: 12
                        color: modelData.cur ? Qt.rgba(1, 1, 1, 0.09) : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 11
                            anchors.rightMargin: 11
                            spacing: 10
                            Text {
                                text: String.fromCodePoint(modelData.d ? 0xF024B : 0xF0224)
                                color: modelData.d ? mock.accent : mock.muted
                                font { family: mock.fam; pixelSize: 19 }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.n
                                color: mock.fg
                                elide: Text.ElideMiddle
                                font { family: mock.fam; pixelSize: 15; bold: modelData.cur }
                            }
                            Text {
                                text: modelData.t
                                color: Qt.rgba(1, 1, 1, 0.26)
                                font { family: mock.fam; pixelSize: 11 }
                            }
                            Text {
                                Layout.preferredWidth: 62
                                text: modelData.s
                                color: Qt.rgba(1, 1, 1, 0.32)
                                horizontalAlignment: Text.AlignRight
                                font { family: mock.fam; pixelSize: 12 }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
