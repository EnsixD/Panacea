import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: picker
    required property var sys
    signal selected(string path)
    signal canceled()
    property string directory: Quickshell.env("HOME")
    property string selection: ""
    property var items: []
    property string error: ""
    color: "#18191c"; radius: 20
    border.width: 1; border.color: "#3b3d41"
    function load(path) { if (!reader.running) { reader.command = ["python3", sys.scriptDir + "/chat-files.py", path]; reader.running = true; } }
    Component.onCompleted: load(directory)
    Process {
        id: reader
        stdout: StdioCollector { onStreamFinished: { try { var d=JSON.parse(text); picker.error=d.error || ""; if (d.path) { picker.directory=d.path; picker.items=d.items; picker.selection=""; } } catch(e) { picker.error=String(e); } } }
    }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 16; spacing: 10
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: picker.sys.tr("Выберите файл"); color: picker.sys.colFg; font { pixelSize: 15; bold: true } }
            Text { text: "×"; color: picker.sys.colFg; font.pixelSize: 22; MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: picker.canceled() } }
        }
        RowLayout {
            Layout.fillWidth: true
            Rectangle { Layout.preferredWidth: 34; Layout.preferredHeight: 32; radius: 10; color: "#303136"; Text { anchors.centerIn: parent; text: "↑"; color: "white" } MouseArea { anchors.fill: parent; onClicked: picker.load(picker.directory + "/..") } }
            Text { Layout.fillWidth: true; text: picker.directory; color: picker.sys.colMuted; elide: Text.ElideMiddle; font.pixelSize: 11 }
        }
        Text { visible: picker.error.length > 0; text: picker.error; color: picker.sys.colCrit; Layout.fillWidth: true; wrapMode: Text.WordWrap }
        ListView {
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 3
            model: picker.items
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width; height: 34; radius: 9
                color: picker.selection === modelData.path ? "#40434a" : (itemMouse.containsMouse ? "#292b30" : "transparent")
                Text { anchors.left: parent.left; anchors.leftMargin: 10; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; color: picker.sys.colFg; text: (modelData.directory ? "▸  " : "·  ") + modelData.name; font.pixelSize: 12 }
                MouseArea { id: itemMouse; anchors.fill: parent; hoverEnabled: true; onClicked: modelData.directory ? picker.load(modelData.path) : picker.selection = modelData.path }
            }
        }
        RowLayout {
            Layout.alignment: Qt.AlignRight; spacing: 8
            Repeater {
                model: [{label:picker.sys.tr("Отмена"), accept:false},{label:picker.sys.tr("Прикрепить"),accept:true}]
                delegate: Rectangle {
                    required property var modelData
                    width: 100; height: 34; radius: 17
                    opacity: modelData.accept && !picker.selection ? 0.4 : 1
                    color: modelData.accept ? picker.sys.colFg : "#303136"
                    Text { anchors.centerIn: parent; text: modelData.label; color: modelData.accept ? picker.sys.colBg : picker.sys.colFg; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; enabled: !modelData.accept || picker.selection.length > 0; onClicked: modelData.accept ? picker.selected(picker.selection) : picker.canceled() }
                }
            }
        }
    }
}
