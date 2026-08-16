import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Менеджер паролей.
//
// Закрыт — виден только запрос пароля (того же, что спрашивает sudo).
// Открыт — список записей: откуда пароль, логин, кнопка «скопировать».
// Через 15 минут без обращений хранилище закрывается само.
FocusScope {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    Component.onCompleted: view.forceActiveFocus()
    FocusGrabber { target: view.sys.vaultUnlocked ? search : pw }

    // любое действие продлевает жизнь открытого хранилища
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        onPositionChanged: view.sys.touchVault()
        z: -1
    }

    function goBack() { view.sys.page = "main"; return true; }
    Keys.onEscapePressed: view.goBack()

    property string editId: ""       // id записи в режиме правки
    property string query: ""

    readonly property var shown: {
        var q = view.query.trim().toLowerCase();
        if (q.length === 0) return view.sys.vaultEntries;
        return view.sys.vaultEntries.filter(function (e) {
            return String(e.label).toLowerCase().indexOf(q) >= 0
                || String(e.login).toLowerCase().indexOf(q) >= 0;
        });
    }

    // поле правки: одно и то же для названия, логина и пароля
    component Field: Rectangle {
        id: fld
        property alias text: fin.text
        property string hint: ""
        property bool secret: false
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        radius: 10
        color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        border.color: fin.activeFocus ? view.sys.colOn : view.sys.colLine
        TextInput {
            id: fin
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            color: view.sys.colFg
            selectByMouse: true
            echoMode: fld.secret && !fin.activeFocus ? TextInput.Password : TextInput.Normal
            passwordCharacter: "•"
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
            onTextEdited: view.sys.touchVault()
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: fin.text.length === 0
                text: fld.hint
                color: Qt.rgba(1, 1, 1, 0.26)
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
            }
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 14

        // ------------------------------------------------------------ шапка
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 12
                color: view.sys.vaultUnlocked ? Qt.rgba(view.sys.colOk.r, view.sys.colOk.g, view.sys.colOk.b, 0.16)
                                              : Qt.rgba(1, 1, 1, 0.08)
                Glyph {
                    anchors.fill: parent
                    glyph: String.fromCodePoint(view.sys.vaultUnlocked ? 0xF0FC6 : 0xF033E)
                    color: view.sys.vaultUnlocked ? view.sys.colOk : view.sys.colMuted
                    fontFam: view.sys.fontFam
                    size: view.sys.iconSize + 2
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: view.sys.tr("Пароли")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    text: view.sys.vaultUnlocked
                          ? view.sys.vaultEntries.length + " " + view.sys.tr("записей")
                          : view.sys.tr("Введите пароль пользователя")
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
            }

            // закрыть хранилище вручную
            Rectangle {
                visible: view.sys.vaultUnlocked
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 11
                color: lockMa.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.06)
                Glyph {
                    anchors.fill: parent
                    glyph: String.fromCodePoint(0xF033E)
                    color: view.sys.colFg
                    fontFam: view.sys.fontFam
                    size: view.sys.iconSize - 2
                }
                MouseArea {
                    id: lockMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // закрыли хранилище — держать пустую страницу с запросом
                    // пароля незачем, уходим к плиткам
                    onClicked: { view.sys.lockVault(); view.sys.page = "main"; }
                }
            }
        }

        // ------------------------------------------------------- ввод пароля
        Rectangle {
            visible: !view.sys.vaultUnlocked
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: 12
            color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            border.color: pw.activeFocus ? view.sys.colOn : view.sys.colLine
            Behavior on border.color { ColorAnimation { duration: 140 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 8

                TextInput {
                    id: pw
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: view.sys.colFg
                    selectByMouse: true
                    enabled: !view.sys.vaultBusy
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize }
                    onAccepted: { view.sys.unlockVault(text); text = ""; }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pw.text.length === 0
                        text: view.sys.tr("Пароль")
                        color: Qt.rgba(1, 1, 1, 0.28)
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize }
                    }
                }

                Text {
                    visible: view.sys.vaultBusy
                    text: view.sys.tr("Проверка…")
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                }
            }
        }

        Text {
            visible: !view.sys.vaultUnlocked && view.sys.vaultError.length > 0
            Layout.fillWidth: true
            text: view.sys.vaultError
            color: view.sys.colCrit
            wrapMode: Text.WordWrap
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
        }

        Text {
            visible: !view.sys.vaultUnlocked
            Layout.fillWidth: true
            text: view.sys.tr("Хранилище шифруется этим же паролем и закрывается само через 15 минут простоя.")
            color: Qt.rgba(1, 1, 1, 0.30)
            wrapMode: Text.WordWrap
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
        }

        // ---------------------------------------------------------- поиск/+
        RowLayout {
            visible: view.sys.vaultUnlocked
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 11
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: search.activeFocus ? view.sys.colOn : view.sys.colLine

                TextInput {
                    id: search
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: view.sys.colFg
                    selectByMouse: true
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                    onTextChanged: { view.query = text; view.sys.touchVault(); }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text.length === 0
                        text: view.sys.tr("Поиск")
                        color: Qt.rgba(1, 1, 1, 0.28)
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                    }
                }
            }

            // поискать пароли в браузерах
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 11
                color: scanMa.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.06)
                opacity: view.sys.browserScanning ? 0.6 : 1

                Glyph {
                    id: scanGlyph
                    anchors.fill: parent
                    // во время поиска — «часы», иначе значок браузера
                    glyph: String.fromCodePoint(view.sys.browserScanning ? 0xF051B : 0xF059F)
                    color: view.sys.colFg
                    fontFam: view.sys.fontFam
                    size: view.sys.iconSize - 2

                    RotationAnimation on rotation {
                        running: view.sys.browserScanning
                        loops: Animation.Infinite
                        from: 0; to: 360; duration: 1400
                        onRunningChanged: if (!running) scanGlyph.rotation = 0
                    }
                }
                MouseArea {
                    id: scanMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.browserScan()
                }
                ToolTip.visible: scanMa.containsMouse
                ToolTip.text: view.sys.tr("Из браузеров")
            }

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 11
                color: addMa.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.06)
                Glyph {
                    anchors.fill: parent
                    glyph: String.fromCodePoint(0xF0415)      // плюс
                    color: view.sys.colFg
                    fontFam: view.sys.fontFam
                    size: view.sys.iconSize - 2
                }
                MouseArea {
                    id: addMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        view.sys.vaultAdd(view.sys.tr("Новая запись"), "", "");
                        view.editId = view.sys.vaultEntries.length
                                      ? view.sys.vaultEntries[0].id : "";
                    }
                }
            }
        }

        // ------------------------------------------- найденное в браузерах
        // Появляется только после поиска: ничего не переносится само,
        // каждую запись человек добавляет сам — или все разом.
        ColumnLayout {
            visible: view.sys.vaultUnlocked
                     && (view.sys.browserScanning || view.sys.browserScanned)
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: view.sys.browserScanning
                          ? view.sys.tr("Ищем в браузерах…")
                          : (view.sys.browserError.length
                             ? view.sys.browserError
                             : (view.sys.browserFound.length
                                ? view.sys.tr("Найдено в браузерах") + " · "
                                  + view.sys.browserFound.length
                                : view.sys.tr("В браузерах ничего нового")))
                    color: view.sys.browserError.length ? view.sys.colCrit : view.sys.colMuted
                    elide: Text.ElideRight
                    font {
                        family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4
                        bold: true; capitalization: Font.AllUppercase; letterSpacing: 1
                    }
                }

                // добавить все разом
                Rectangle {
                    visible: view.sys.browserFound.length > 1
                    Layout.preferredWidth: allTxt.implicitWidth + 20
                    Layout.preferredHeight: 26
                    radius: 9
                    color: allMa.containsMouse ? Qt.rgba(view.sys.colOk.r, view.sys.colOk.g, view.sys.colOk.b, 0.28)
                                               : Qt.rgba(view.sys.colOk.r, view.sys.colOk.g, view.sys.colOk.b, 0.16)
                    Text {
                        id: allTxt
                        anchors.centerIn: parent
                        text: view.sys.tr("Добавить все")
                        color: view.sys.colOk
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                    }
                    MouseArea {
                        id: allMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.browserImportAll()
                    }
                }
            }

            ListView {
                visible: view.sys.browserFound.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight:
                    Math.min(200, Math.max(0, view.sys.browserFound.length * 50))
                clip: true
                spacing: 6
                model: view.sys.browserFound
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { radius: 2; color: Qt.rgba(1, 1, 1, 0.22) }
                }

                delegate: Rectangle {
                    id: found
                    required property var modelData
                    width: ListView.view.width
                    height: 44
                    radius: 11
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: view.sys.colLine

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 10

                        Glyph {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            glyph: String.fromCodePoint(0xF059F)
                            color: view.sys.colMuted
                            fontFam: view.sys.fontFam
                            size: view.sys.iconSize - 5
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: String(found.modelData.url || "")
                                color: view.sys.colFg
                                elide: Text.ElideRight
                                font {
                                    family: view.sys.fontFam
                                    pixelSize: view.sys.fontSize - 3
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: String(found.modelData.login || "") + "   "
                                      + String(found.modelData.browser || "")
                                color: view.sys.colMuted
                                elide: Text.ElideRight
                                font {
                                    family: view.sys.fontFam
                                    pixelSize: view.sys.fontSize - 5
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 10
                            color: impMa.containsMouse ? Qt.rgba(view.sys.colOk.r, view.sys.colOk.g, view.sys.colOk.b, 0.28)
                                                       : Qt.rgba(1, 1, 1, 0.07)
                            Glyph {
                                anchors.fill: parent
                                glyph: String.fromCodePoint(0xF0415)   // плюс
                                color: impMa.containsMouse ? view.sys.colOk : view.sys.colFg
                                fontFam: view.sys.fontFam
                                size: view.sys.iconSize - 4
                            }
                            MouseArea {
                                id: impMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.sys.browserImport(found.modelData)
                            }
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------------ список
        ListView {
            id: list
            visible: view.sys.vaultUnlocked
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(360, Math.max(0, view.shown.length * 62))
            clip: true
            spacing: 6
            model: view.shown
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { radius: 2; color: Qt.rgba(1, 1, 1, 0.22) }
            }

            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property bool editing: view.editId === row.modelData.id

                width: list.width
                height: row.editing ? 112 : 56
                radius: 12
                color: rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: view.sys.colLine
                Behavior on height { NumberAnimation { duration: view.sys.animQuick } }
                Behavior on color { ColorAnimation { duration: 140 } }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onContainsMouseChanged: if (containsMouse) view.sys.touchVault()
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 9
                            color: Qt.rgba(1, 1, 1, 0.08)
                            Glyph {
                                anchors.fill: parent
                                glyph: String.fromCodePoint(0xF0306)     // ключ
                                color: view.sys.colMuted
                                fontFam: view.sys.fontFam
                                size: view.sys.iconSize - 4
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: String(row.modelData.label)
                                color: view.sys.colFg
                                elide: Text.ElideRight
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2; bold: true }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: String(row.modelData.login).length
                                      ? String(row.modelData.login) + "   " + String(row.modelData.at)
                                      : String(row.modelData.at)
                                color: view.sys.colMuted
                                elide: Text.ElideRight
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5 }
                            }
                        }

                        // скопировать пароль
                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 10
                            color: copyMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)
                            Glyph {
                                anchors.fill: parent
                                glyph: String.fromCodePoint(copyMa.done ? 0xF012C : 0xF018F)
                                color: copyMa.done ? view.sys.colOk : view.sys.colFg
                                fontFam: view.sys.fontFam
                                size: view.sys.iconSize - 4
                            }
                            MouseArea {
                                id: copyMa
                                property bool done: false
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    view.sys.vaultCopy(String(row.modelData.pw));
                                    done = true; doneTimer.restart();
                                }
                                Timer { id: doneTimer; interval: 1200; onTriggered: copyMa.done = false }
                            }
                        }

                        // правка
                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 10
                            color: editMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)
                            Glyph {
                                anchors.fill: parent
                                glyph: String.fromCodePoint(0xF03EB)     // карандаш
                                color: view.sys.colFg
                                fontFam: view.sys.fontFam
                                size: view.sys.iconSize - 4
                            }
                            MouseArea {
                                id: editMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.editId = row.editing ? "" : String(row.modelData.id)
                            }
                        }

                        // удалить
                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 10
                            color: delMa.containsMouse ? Qt.rgba(1, 0.27, 0.27, 0.18) : Qt.rgba(1, 1, 1, 0.07)
                            Glyph {
                                anchors.fill: parent
                                glyph: String.fromCodePoint(0xF01B4)     // корзина
                                color: delMa.containsMouse ? view.sys.colCrit : view.sys.colFg
                                fontFam: view.sys.fontFam
                                size: view.sys.iconSize - 4
                            }
                            MouseArea {
                                id: delMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.sys.vaultRemove(String(row.modelData.id))
                            }
                        }
                    }

                    // строка правки: название, логин, пароль
                    RowLayout {
                        visible: row.editing
                        Layout.fillWidth: true
                        spacing: 6

                        Field { id: fLabel; text: String(row.modelData.label); hint: view.sys.tr("Название") }
                        Field { id: fLogin; text: String(row.modelData.login); hint: view.sys.tr("Логин") }
                        Field { id: fPw; text: String(row.modelData.pw); hint: view.sys.tr("Пароль"); secret: true }

                        Rectangle {
                            Layout.preferredWidth: 60
                            Layout.preferredHeight: 32
                            radius: 10
                            color: okMa.containsMouse ? Qt.rgba(view.sys.colOk.r, view.sys.colOk.g, view.sys.colOk.b, 0.28)
                                                      : Qt.rgba(view.sys.colOk.r, view.sys.colOk.g, view.sys.colOk.b, 0.16)
                            Text {
                                anchors.centerIn: parent
                                text: view.sys.tr("ОК")
                                color: view.sys.colOk
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                            }
                            MouseArea {
                                id: okMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    view.sys.vaultUpdate(String(row.modelData.id),
                                                         fLabel.text, fLogin.text, fPw.text);
                                    view.editId = "";
                                }
                            }
                        }
                    }
                }
            }
        }

        Text {
            visible: view.sys.vaultUnlocked && view.shown.length === 0
            Layout.fillWidth: true
            text: view.query.length ? view.sys.tr("Ничего не найдено")
                                    : view.sys.tr("Пока ни одного пароля")
            color: view.sys.colMuted
            horizontalAlignment: Text.AlignHCenter
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
        }
    }
}
