import QtQuick
import QtQuick.Layouts

// Пульт записи экрана: состояние, настройки и кнопки.
// Открывается наведением на пилюлю, пока идёт запись, или из плиток.
Item {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    focus: true
    Component.onCompleted: {
        forceActiveFocus();
        if (view.sys.cfg.recMic) view.sys.refreshMics();
    }
    // Esc возвращает к плиткам, а не закрывает пилюлю целиком: страницу
    // открыли из quick settings, туда же логично и вернуться.
    function goBack() { view.sys.page = "main"; return true; }
    Keys.onEscapePressed: view.goBack()

    readonly property var fpsOptions: [30, 60, 120]
    readonly property var dirOptions: ["~/Videos", "~/Pictures", "~/Desktop", "~/"]

    function prettyDir(d) {
        return String(d).replace("~/", "").length ? String(d) : "~";
    }

    // --------------------------------------------------------- общие кусочки
    component Chip: Rectangle {
        property string label: ""
        property bool active: false
        signal picked()

        implicitWidth: chipText.implicitWidth + 22
        implicitHeight: 30
        radius: 15
        color: active ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.18)
             : (chipMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
        border.color: active ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g,
                                       view.sys.colOn.b, 0.45)
                             : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        scale: chipMa.pressed ? 0.94 : 1.0
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

        Text {
            id: chipText
            anchors.centerIn: parent
            text: parent.label
            color: parent.active ? view.sys.colFg : view.sys.colMuted
            font {
                family: view.sys.fontFam
                pixelSize: view.sys.fontSize - 3
                bold: parent.active
            }
        }
        MouseArea {
            id: chipMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.picked()
        }
    }

    // переключатель со строкой-подписью
    component Toggle: Rectangle {
        property string label: ""
        property string glyph: ""
        property bool checked: false
        signal toggled()

        Layout.fillWidth: true
        Layout.preferredHeight: 40
        radius: 12
        color: tglMa.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.04)
        Behavior on color { ColorAnimation { duration: 150 } }
        opacity: view.sys.recActive ? 0.45 : 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Glyph {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                glyph: parent.parent.glyph
                color: parent.parent.checked ? view.sys.colOn : view.sys.colMuted
                fontFam: view.sys.fontFam
                size: view.sys.iconSize - 2
            }
            Text {
                Layout.fillWidth: true
                text: parent.parent.label
                color: parent.parent.checked ? view.sys.colFg : view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
            }
            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 21
                radius: 11
                color: parent.parent.checked ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.14)
                Behavior on color { ColorAnimation { duration: 180 } }
                Rectangle {
                    width: 17; height: 17; radius: 9
                    y: 2
                    x: parent.parent.parent.checked ? parent.width - width - 2 : 2
                    // Включённая дорожка налита акцентом, и белый кружок на
                    // ней пропадает — тумблер выглядит просто белой плашкой.
                    // На выключенной дорожка тёмная, там белый и нужен.
                    color: parent.parent.parent.checked
                           ? view.sys.fgOn(view.sys.colOn) : "#ffffff"
                    Behavior on x {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                }
            }
        }

        MouseArea {
            id: tglMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: !view.sys.recActive
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.toggled()
        }
    }

    // строка выбора микрофона
    component MicRow: Rectangle {
        property string label: ""
        property string device: ""
        readonly property bool active: view.sys.cfg.recMicDevice === device

        Layout.fillWidth: true
        Layout.preferredHeight: 30
        radius: 9
        color: micMa.containsMouse ? view.sys.colHover
             : (active ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
        Behavior on color { ColorAnimation { duration: 130 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Text {
                text: String.fromCodePoint(parent.parent.active ? 0xF0765 : 0xF0766)
                color: parent.parent.active ? view.sys.colOn : view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: 12 }
            }
            Text {
                Layout.fillWidth: true
                text: parent.parent.label
                color: parent.parent.active ? view.sys.colFg : view.sys.colMuted
                elide: Text.ElideRight
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
            }
        }

        MouseArea {
            id: micMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: !view.sys.recActive
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                view.sys.cfg.recMicDevice = parent.device;
                view.sys.saveCfgNow();
            }
        }
    }

    component BigButton: Rectangle {
        property string glyph: ""
        property string label: ""
        property color tint: view.sys.colOn
        property bool filled: false
        signal pressedAction()

        Layout.fillWidth: true
        Layout.preferredHeight: 46
        radius: 14
        color: filled ? Qt.rgba(tint.r, tint.g, tint.b, bigMa.containsMouse ? 0.34 : 0.22)
                      : (bigMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
        border.color: filled ? Qt.rgba(tint.r, tint.g, tint.b, 0.5) : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 150 } }
        scale: bigMa.pressed ? 0.96 : 1.0
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

        RowLayout {
            anchors.centerIn: parent
            spacing: 9
            Glyph {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                glyph: parent.parent.glyph
                color: parent.parent.filled ? parent.parent.tint : view.sys.colFg
                fontFam: view.sys.fontFam
                size: view.sys.iconSize
            }
            Text {
                text: parent.parent.label
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2; bold: true }
            }
        }

        MouseArea {
            id: bigMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.pressedAction()
        }
    }

    // ------------------------------------------------------------------ вид
    ColumnLayout {
        id: col
        width: parent.width
        spacing: 12

        // ---------------------------------------------------------- шапка
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 11
                Layout.preferredHeight: 11
                Layout.alignment: Qt.AlignVCenter
                radius: 6
                color: !view.sys.recActive ? view.sys.colMuted
                     : view.sys.recPaused ? view.sys.colWarn : view.sys.colCrit
                Behavior on color { ColorAnimation { duration: 200 } }

                SequentialAnimation on opacity {
                    running: view.sys.recActive && !view.sys.recPaused
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 620; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0;  duration: 620; easing.type: Easing.InOutSine }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: !view.sys.recActive ? view.sys.tr("Запись экрана")
                        : view.sys.recPaused  ? view.sys.tr("Пауза")
                                              : view.sys.tr("Идёт запись")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    text: view.sys.recError.length ? view.sys.recError
                        : view.sys.recActive
                          ? view.sys.recFile.split("/").pop()
                          : view.sys.tr("Готово к записи")
                    color: view.sys.recError.length ? view.sys.colCrit : view.sys.colMuted
                    elide: Text.ElideMiddle
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                }
            }

            // таймер
            Text {
                visible: view.sys.recActive
                text: view.sys.recTimeText
                color: view.sys.recPaused ? view.sys.colWarn : view.sys.colCrit
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 4; bold: true }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: view.sys.colLine
        }

        // ------------------------------------------------------------ FPS
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.preferredWidth: 74
                text: "FPS"
                color: view.sys.colMuted
                font {
                    family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4
                    bold: true; capitalization: Font.AllUppercase; letterSpacing: 1
                }
            }
            Repeater {
                model: view.fpsOptions
                Chip {
                    required property var modelData
                    label: String(modelData)
                    active: view.sys.cfg.recFps === modelData
                    // на ходу менять нечего: wf-recorder читает fps при старте
                    enabled: !view.sys.recActive
                    opacity: view.sys.recActive ? 0.45 : 1
                    onPicked: {
                        view.sys.cfg.recFps = modelData;
                        view.sys.saveCfgNow();
                    }
                }
            }
            Item { Layout.fillWidth: true }
        }

        // ---------------------------------------------------------- папка
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.preferredWidth: 74
                text: view.sys.tr("Папка")
                color: view.sys.colMuted
                font {
                    family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4
                    bold: true; capitalization: Font.AllUppercase; letterSpacing: 1
                }
            }
            Repeater {
                model: view.dirOptions
                Chip {
                    required property var modelData
                    label: String(modelData)
                    active: view.sys.cfg.recDir === modelData
                    enabled: !view.sys.recActive
                    opacity: view.sys.recActive ? 0.45 : 1
                    onPicked: {
                        view.sys.cfg.recDir = modelData;
                        view.sys.saveCfgNow();
                    }
                }
            }
            Item { Layout.fillWidth: true }
        }

        // ----------------------------------------------------------- звук
        Toggle {
            label: view.sys.tr("Звук системы")
            glyph: String.fromCodePoint(view.sys.cfg.recSysAudio ? 0xF057E : 0xF0581)
            checked: view.sys.cfg.recSysAudio
            onToggled: {
                view.sys.cfg.recSysAudio = !view.sys.cfg.recSysAudio;
                view.sys.saveCfgNow();
            }
        }

        Toggle {
            label: view.sys.tr("Микрофон")
            glyph: String.fromCodePoint(view.sys.cfg.recMic ? 0xF036C : 0xF036D)
            checked: view.sys.cfg.recMic
            onToggled: {
                view.sys.cfg.recMic = !view.sys.cfg.recMic;
                view.sys.saveCfgNow();
                if (view.sys.cfg.recMic) view.sys.refreshMics();
            }
        }

        // выбор микрофона — только когда он включён
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            spacing: 2
            visible: view.sys.cfg.recMic
            opacity: view.sys.recActive ? 0.45 : 1

            MicRow {
                label: view.sys.tr("По умолчанию")
                device: ""
            }
            Repeater {
                model: view.sys.recMics
                MicRow {
                    required property var model
                    label: model.mDesc
                    device: model.mName
                }
            }
        }

        // -------------------------------------------------------- кнопки
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 9

            BigButton {
                visible: !view.sys.recActive
                glyph: String.fromCodePoint(0xF044A)   // md-record
                label: view.sys.tr("Начать запись")
                tint: view.sys.colCrit
                filled: true
                onPressedAction: view.sys.startRecord()
            }

            BigButton {
                visible: view.sys.recActive
                glyph: String.fromCodePoint(view.sys.recPaused ? 0xF040A : 0xF03E4)
                label: view.sys.recPaused ? view.sys.tr("Продолжить")
                                          : view.sys.tr("Пауза")
                tint: view.sys.colWarn
                filled: view.sys.recPaused
                onPressedAction: view.sys.pauseRecord()
            }

            BigButton {
                visible: view.sys.recActive
                glyph: String.fromCodePoint(0xF04DB)   // md-stop
                label: view.sys.tr("Закончить")
                tint: view.sys.colCrit
                filled: true
                onPressedAction: view.sys.stopRecord()
            }
        }

        // папка с записями
        RowLayout {
            Layout.fillWidth: true
            spacing: 9

            BigButton {
                glyph: String.fromCodePoint(0xF0770)   // md-folder_open
                label: view.sys.tr("Открыть папку с записями")
                onPressedAction: view.sys.openRecordDir()
            }
        }

        // куда сохранится файл — видно до старта
        Text {
            Layout.fillWidth: true
            visible: !view.sys.recActive
            text: view.sys.tr("Файл ляжет в ") + view.sys.cfg.recDir
            color: Qt.rgba(1, 1, 1, 0.30)
            elide: Text.ElideMiddle
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5 }
        }
    }
}
