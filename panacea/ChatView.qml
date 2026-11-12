import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: view
    required property var sys
    implicitHeight: 520
    property string service: sys.islandChatService
    onServiceChanged: sys.islandChatService = service
    Connections { target: view.sys; function onIslandChatServiceChanged() { if (view.service !== view.sys.islandChatService) view.service = view.sys.islandChatService; } }
    property var attachments: []
    property bool busy: false
    property string payload: ""
    property bool pickerOpen: sys.chatFilePickerOpen
    readonly property var visibleEvents: sys.islandAgentEvents.filter(e =>
        !/требуется подтверждение|permission|approval|подтверждение/i.test(e.title)
        && (sys.cfg.agentEventFilter === "all" || (e.app + " " + e.title).toLowerCase().indexOf(sys.cfg.agentEventFilter) >= 0))
    function goBack() { if (sys.chatFilePickerOpen) { sys.chatFilePickerOpen = false; return true; } return false; }
    Connections { target: view.sys; function onChatFilesPicked(paths) { view.attachments = view.attachments.concat(paths); } }
    Process {
        id: pasteImage
        command: ["python3", view.sys.scriptDir + "/chat-paste-image.py"]
        stdout: StdioCollector { onStreamFinished: {
            var path = String(text).trim();
            if (path) view.attachments = view.attachments.concat([path]);
            else input.paste();
        } }
    }
    Process {
        id: request
        command: ["python3", view.sys.scriptDir + "/chat.py"]
        stdinEnabled: true
        onStarted: { write(view.payload + "\n"); stdinEnabled = false; }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var result = JSON.parse(text);
                    var arr = view.sys.islandChatMessages.slice();
                    arr.push({role: "assistant", content: result.answer || ("Ошибка: " + result.error)});
                    view.sys.islandChatMessages = arr;
                } catch (e) {
                    var arr2 = view.sys.islandChatMessages.slice();
                    arr2.push({role:"assistant", content:"Не удалось получить ответ."});
                    view.sys.islandChatMessages = arr2;
                }
                view.busy = false;
            }
        }
    }
    function send() {
        var msg = input.text.trim();
        if ((!msg && !attachments.length) || busy) return;
        var a = sys.islandChatMessages.slice();
        a.push({role:"user", content:msg}); sys.islandChatMessages = a;
        payload = JSON.stringify({messages:a, files:attachments});
        attachments = []; input.text = ""; busy = true;
        request.stdinEnabled = true; request.running = true;
    }
    readonly property var services: ({gemini:"https://gemini.google.com/", chatgpt:"https://chatgpt.com/", deepseek:"https://chat.deepseek.com/"})
    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        Row {
            Layout.alignment: Qt.AlignLeft
            spacing: 4
            Repeater {
                model: [{id:"chat", name:view.sys.tr("Остров"), glyph:0xF0642},{id:"gemini", name:"Gemini", glyph:0xF059F},{id:"chatgpt", name:"ChatGPT", glyph:0xF059F},{id:"deepseek", name:"DeepSeek", glyph:0xF059F}]
                delegate: Rectangle {
                    required property var modelData
                    width: serviceName.implicitWidth + 35
                    height: 32; radius: 16
                    color: view.service === modelData.id ? Qt.rgba(1,1,1,0.12) : "transparent"
                    Row {
                        anchors.centerIn: parent; spacing: 6
                        Text { anchors.verticalCenter: parent.verticalCenter; visible: modelData.id === "chat"; text: "✦"; color: view.service === modelData.id ? view.sys.colFg : view.sys.colMuted; font.pixelSize: 16 }
                        Glyph { anchors.verticalCenter: parent.verticalCenter; visible: modelData.id !== "chat"; glyph: String.fromCodePoint(modelData.glyph); fontFam: view.sys.fontFam; size: 16; color: view.service === modelData.id ? view.sys.colFg : view.sys.colMuted }
                        Text { id: serviceName; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; color: view.sys.colFg; font { family: view.sys.fontBody; pixelSize: 11; bold: true } }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: view.service = modelData.id }
                }
            }
        }
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            visible: view.service !== "chat"
            Loader {
                id: webLoader
                anchors.fill: parent
                // The startup wrapper supplies the argv workaround required by QtWebEngine.
                active: view.service !== "chat" && Quickshell.env("PANACEA_WEBENGINE_READY") === "1"
                source: "IslandWebView.qml"
                onLoaded: { item.url = view.services[view.service]; }
            }
            Connections { target: view; function onServiceChanged() { if (webLoader.item && view.service !== "chat") webLoader.item.url = view.services[view.service]; } }
            Column {
                anchors.centerIn: parent; width: parent.width - 30; spacing: 12
                visible: !webLoader.active || webLoader.status === Loader.Error
                Text { width: parent.width; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; color: view.sys.colMuted; text: view.sys.tr("Встроенный браузер недоступен. Откройте сервис в обычном браузере.") }
                Button { anchors.horizontalCenter: parent.horizontalCenter; text: view.sys.tr("Открыть") + " " + view.service; onClicked: Qt.openUrlExternally(view.services[view.service]) }
            }
        }
        ScrollView {
            id: scroll
            Layout.fillWidth: true; Layout.fillHeight: true
            visible: view.service === "chat"
            contentWidth: availableWidth
            Column {
                width: scroll.availableWidth; spacing: 10

                Repeater {
                    model: view.visibleEvents
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width; height: eventText.implicitHeight + 20; radius: 12
                        color: Qt.rgba(1,1,1,0.06)
                        Text { id: eventText; x: 10; y: 10; width: parent.width - 20; text: modelData.app + ": " + modelData.title + (modelData.body ? "\n" + modelData.body : ""); color: view.sys.colFg; wrapMode: Text.Wrap; textFormat: Text.PlainText; font.pixelSize: 12 }
                    }
                }
                Repeater {
                    model: view.sys.islandChatMessages
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width; height: message.implicitHeight + 20; radius: 12
                        color: modelData.role === "user" ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.04)
                        Text { id: message; x: 10; y: 10; width: parent.width - 20; text: modelData.content; color: view.sys.colFg; wrapMode: Text.Wrap; textFormat: Text.PlainText; font.pixelSize: 13 }
                    }
                }
                Text { visible: view.busy; text: view.sys.tr("Думаю…"); color: view.sys.colMuted }
            }
            onContentHeightChanged: if (contentItem) contentItem.contentY = Math.max(0, contentHeight - availableHeight)
        }
        RowLayout {
            visible: view.service === "chat" && view.attachments.length > 0
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: view.sys.tr("Прикреплено файлов:") + " " + view.attachments.length; color: view.sys.colMuted }
            Text { text: "×"; color: view.sys.colMuted; font.pixelSize: 18; MouseArea { anchors.fill: parent; anchors.margins: -5; onClicked: view.attachments = [] } }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 8; Layout.rightMargin: 8
            Layout.preferredHeight: Math.max(50, Math.min(110, input.contentHeight + 20))
            visible: view.service === "chat"
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.07)
            border.width: 1
            border.color: input.activeFocus ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.07)
            RowLayout {
                anchors.fill: parent; anchors.margins: 6; spacing: 8
                Rectangle {
                    Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 18
                    color: attachMouse.containsMouse ? Qt.rgba(1,1,1,0.16) : Qt.rgba(1,1,1,0.07)
                    Glyph { anchors.centerIn: parent; glyph: String.fromCodePoint(0xF03E2); fontFam: view.sys.fontFam; size: 19; color: view.sys.colFg }
                    MouseArea { id: attachMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: view.sys.chatFilePickerOpen = true }
                }
                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Flickable {
                        id: inputScroll; anchors.fill: parent; clip: true
                        contentWidth: width; contentHeight: Math.max(height, input.contentHeight)
                        TextEdit {
                            id: input; width: inputScroll.width; y: Math.max(0, (inputScroll.height - contentHeight) / 2); height: contentHeight
                            color: view.sys.colFg; font { family: view.sys.fontBody; pixelSize: 13 }
                            wrapMode: TextEdit.Wrap; selectByMouse: true
                            onCursorRectangleChanged: {
                                if (cursorRectangle.y + cursorRectangle.height > inputScroll.contentY + inputScroll.height) inputScroll.contentY = cursorRectangle.y + cursorRectangle.height - inputScroll.height;
                                else if (cursorRectangle.y < inputScroll.contentY) inputScroll.contentY = cursorRectangle.y;
                            }
                            Keys.onPressed: event => {
                                if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) { if (!pasteImage.running) pasteImage.running = true; event.accepted = true; }
                                else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) { view.send(); event.accepted = true; }
                            }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; visible: !input.text; text: view.sys.tr("Сообщение…"); color: view.sys.colMuted; font { family: view.sys.fontBody; pixelSize: 13 } }
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 18
                    color: !view.busy && (input.text.trim().length || view.attachments.length) ? view.sys.colFg : Qt.rgba(1,1,1,0.09)
                    Text { anchors.centerIn: parent; text: "↑"; color: !view.busy && (input.text.trim().length || view.attachments.length) ? view.sys.colBg : view.sys.colMuted; font { pixelSize: 21; bold: true } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !view.busy && (input.text.trim().length || view.attachments.length) > 0; onClicked: view.send() }
                }
            }
        }
    }
    Column {
        anchors.centerIn: parent
        width: parent.width - 60
        spacing: 8
        visible: view.service === "chat" && view.sys.islandChatMessages.length === 0 && view.visibleEvents.length === 0 && !view.busy && !view.pickerOpen
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "✦"; color: view.sys.colFg; font.pixelSize: 28 }
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: view.sys.tr("Спросите что угодно"); color: view.sys.colFg; font { family: view.sys.fontDisplay; pixelSize: 19; bold: true } }
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; text: view.sys.tr("Добавьте адрес API, модель и ключ в настройках лаунчера."); color: view.sys.colMuted; font.pixelSize: 12 }
    }
}
