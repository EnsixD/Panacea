import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell.Io

Item {
    id: view
    required property var sys
    implicitHeight: 520
    property string service: "chat"
    property var attachments: []
    property bool busy: false
    property string payload: ""
    FileDialog {
        id: picker
        fileMode: FileDialog.OpenFiles
        onAccepted: {
            var list = [];
            for (var i = 0; i < selectedFiles.length; i++) {
                var p = decodeURIComponent(String(selectedFiles[i]).replace(/^file:\/\//, ""));
                list.push(p);
            }
            view.attachments = list;
        }
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
        if (!msg || busy) return;
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
        RowLayout {
            Layout.fillWidth: true
            Repeater {
                model: [{id:"chat", name:view.sys.tr("Остров")},{id:"gemini", name:"Gemini"},{id:"chatgpt", name:"ChatGPT"},{id:"deepseek", name:"DeepSeek"}]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 32; radius: 10
                    color: view.service === modelData.id ? view.sys.colFg : Qt.rgba(1,1,1,0.07)
                    Text { anchors.centerIn: parent; text: modelData.name; color: view.service === modelData.id ? view.sys.colBg : view.sys.colFg; font.pixelSize: 12 }
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
                active: view.service !== "chat"
                source: "IslandWebView.qml"
                onLoaded: { item.url = view.services[view.service]; }
            }
            Connections { target: view; function onServiceChanged() { if (webLoader.item && view.service !== "chat") webLoader.item.url = view.services[view.service]; } }
            Column {
                anchors.centerIn: parent; width: parent.width - 30; spacing: 12
                visible: webLoader.status === Loader.Error
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
                Text { visible: view.sys.islandChatMessages.length === 0; width: parent.width; wrapMode: Text.WordWrap; color: view.sys.colMuted; text: view.sys.tr("Напишите сообщение. Адрес API и модель задаются в настройках лаунчера.") }
                Repeater {
                    model: view.sys.islandAgentEvents
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
        Text { Layout.fillWidth: true; visible: view.service === "chat" && view.attachments.length > 0; text: view.sys.tr("Прикреплено файлов:") + " " + view.attachments.length; color: view.sys.colMuted }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            visible: view.service === "chat"
            radius: 16
            color: Qt.rgba(1, 1, 1, 0.07)
            border.width: 1
            border.color: input.activeFocus ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.07)
            RowLayout {
                anchors.fill: parent; anchors.margins: 6; spacing: 8
                Rectangle {
                    Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 12
                    color: attachMouse.containsMouse ? Qt.rgba(1,1,1,0.16) : Qt.rgba(1,1,1,0.07)
                    Text { anchors.centerIn: parent; text: "+"; color: view.sys.colFg; font.pixelSize: 23 }
                    MouseArea { id: attachMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: picker.open() }
                }
                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    TextInput {
                        id: input; anchors.fill: parent; verticalAlignment: TextInput.AlignVCenter
                        color: view.sys.colFg; font { family: view.sys.fontBody; pixelSize: 13 }
                        clip: true; selectByMouse: true; onAccepted: view.send()
                    }
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: !input.text && !input.activeFocus; text: view.sys.tr("Сообщение…"); color: view.sys.colMuted; font { family: view.sys.fontBody; pixelSize: 13 } }
                }
                Rectangle {
                    Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 12
                    color: !view.busy && input.text.trim().length ? view.sys.colFg : Qt.rgba(1,1,1,0.09)
                    Text { anchors.centerIn: parent; text: "↑"; color: !view.busy && input.text.trim().length ? view.sys.colBg : view.sys.colMuted; font { pixelSize: 21; bold: true } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !view.busy && input.text.trim().length > 0; onClicked: view.send() }
                }
            }
        }
    }
}
