import QtQuick
import QtQuick.Layouts
import Quickshell.Io

ColumnLayout {
    id: view
    property var sys
    property bool busy: false
    property string result: ""
    readonly property var paths: view.sys.quickFilePaths
    readonly property string path: paths.length ? paths[0] : ""
    readonly property string filename: path.split('/').pop()
    readonly property bool isImage: paths.length > 0 && paths.every(p => /\.(png|jpg|jpeg|webp|bmp|tiff?)$/i.test(p))
    readonly property bool isArchive: paths.length > 0 && paths.every(p => /\.(zip|tar|tar\.gz|tgz|tar\.xz|tar\.bz2)$/i.test(p))
    implicitHeight: content.implicitHeight
    Process {
        id: action
        stdout: StdioCollector { onStreamFinished: view.result = text.trim() }
        onExited: (code, status) => {
            view.busy = false;
            if (code !== 0) view.result = view.sys.tr("Не удалось выполнить действие");
        }
    }
    Process {
        id: clipboard
        onExited: (code, status) => {
            view.result = code === 0 ? view.sys.tr("Путь скопирован") : view.sys.tr("Не удалось выполнить действие");
        }
    }
    Process { id: externalApp }
    function openDetached(args) {
        externalApp.command = args;
        externalApp.startDetached();
    }
    function run(op) {
        if (busy) return;
        busy = true; result = "";
        action.command = ["python3", view.sys.scriptDir + "/quick-file.py", op].concat(paths);
        action.running = true;
    }
    component ActionRow: Rectangle {
        id: row
        property string icon: ""
        property string label: ""
        property bool available: true
        signal triggered()
        Layout.fillWidth: true
        implicitHeight: 47
        radius: 14
        color: hit.containsMouse && available ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.045)
        border.color: hit.containsMouse && available ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.48) : view.sys.colLine
        border.width: 1
        opacity: available ? 1 : 0.45
        Behavior on color { ColorAnimation { duration: view.sys.animFast } }
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 11
            Rectangle {
                Layout.preferredWidth: 29; Layout.preferredHeight: 29; radius: 10
                color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.13)
                Text { anchors.centerIn: parent; text: row.icon; color: view.sys.colOn; font { family: view.sys.fontFam; pixelSize: 15 } }
            }
            Text {
                Layout.fillWidth: true; text: row.label; color: view.sys.colFg; elide: Text.ElideRight
                font { family: view.sys.fontFam; pixelSize: 12; bold: true }
            }
            Text { text: "›"; color: view.sys.colMuted; font { family: view.sys.fontFam; pixelSize: 18 } }
        }
        MouseArea { id: hit; anchors.fill: parent; enabled: row.available; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: row.triggered() }
    }
    ColumnLayout {
        id: content
        Layout.fillWidth: true; spacing: 7
        RowLayout {
            Layout.fillWidth: true; spacing: 10
            Rectangle {
                Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 13
                color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.16)
                Text { anchors.centerIn: parent; text: "󰈙"; color: view.sys.colOn; font { family: view.sys.fontFam; pixelSize: 20 } }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Text { text: view.sys.tr("Быстрые действия"); color: view.sys.colFg; font { family: view.sys.fontFam; pixelSize: 15; bold: true } }
                Text { Layout.fillWidth: true; text: view.paths.length === 1 ? view.filename : view.paths.length + " " + view.sys.tr("файлов"); elide: Text.ElideMiddle; color: view.sys.colMuted; font { family: view.sys.fontFam; pixelSize: 10 } }
            }
        }
        Item { Layout.preferredHeight: 2 }
        ActionRow {
            icon: "󰆏"; label: view.sys.tr("Скопировать путь")
            onTriggered: {
                if (clipboard.running) return;
                clipboard.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", view.paths.join("\n")];
                clipboard.running = true;
            }
        }
        ActionRow { icon: "󰉋"; label: view.sys.tr("Открыть папку"); onTriggered: view.openDetached(["xdg-open", view.path.substring(0, view.path.lastIndexOf('/')) || "/"]) }
        ActionRow {
            icon: "󰇮"; label: view.sys.tr("Прикрепить к письму")
            onTriggered: { var args = ["xdg-email"]; for (var i = 0; i < view.paths.length; ++i) args.push("--attach", view.paths[i]); view.openDetached(args); }
        }
        ActionRow { visible: view.isImage; icon: "󰋩"; label: view.sys.tr("Сжать изображение в WebP"); available: !view.busy; onTriggered: view.run("compress") }
        ActionRow { visible: view.isArchive; icon: "󰗄"; label: view.sys.tr("Извлечь в новую папку"); available: !view.busy; onTriggered: view.run("extract") }
        Text {
            Layout.fillWidth: true; visible: view.busy || view.result.length > 0
            text: view.busy ? view.sys.tr("Выполняется…") : view.result
            color: view.sys.colMuted; wrapMode: Text.WrapAnywhere
            font { family: view.sys.fontFam; pixelSize: 10 }
        }
    }
}
