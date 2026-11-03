import QtQuick
import QtQuick.Layouts
import Quickshell.Io

ColumnLayout {
    id: view
    property var sys
    property bool busy: false
    property string result: ""
    readonly property var paths: sys.quickFilePaths
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
            view.result = code === 0 ? sys.tr("Путь скопирован") : sys.tr("Не удалось выполнить действие");
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
        action.command = ["python3", sys.scriptDir + "/quick-file.py", op].concat(paths);
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
        border.color: hit.containsMouse && available ? Qt.rgba(sys.colOn.r, sys.colOn.g, sys.colOn.b, 0.48) : sys.colLine
        border.width: 1
        opacity: available ? 1 : 0.45
        Behavior on color { ColorAnimation { duration: sys.animFast } }
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 11
            Rectangle {
                Layout.preferredWidth: 29; Layout.preferredHeight: 29; radius: 10
                color: Qt.rgba(sys.colOn.r, sys.colOn.g, sys.colOn.b, 0.13)
                Text { anchors.centerIn: parent; text: row.icon; color: sys.colOn; font { family: sys.fontFam; pixelSize: 15 } }
            }
            Text {
                Layout.fillWidth: true; text: row.label; color: sys.colFg; elide: Text.ElideRight
                font { family: sys.fontFam; pixelSize: 12; bold: true }
            }
            Text { text: "›"; color: sys.colMuted; font { family: sys.fontFam; pixelSize: 18 } }
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
                color: Qt.rgba(sys.colOn.r, sys.colOn.g, sys.colOn.b, 0.16)
                Text { anchors.centerIn: parent; text: "󰈙"; color: sys.colOn; font { family: sys.fontFam; pixelSize: 20 } }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Text { text: sys.tr("Быстрые действия"); color: sys.colFg; font { family: sys.fontFam; pixelSize: 15; bold: true } }
                Text { Layout.fillWidth: true; text: view.paths.length === 1 ? view.filename : view.paths.length + " " + sys.tr("файлов"); elide: Text.ElideMiddle; color: sys.colMuted; font { family: sys.fontFam; pixelSize: 10 } }
            }
        }
        Item { Layout.preferredHeight: 2 }
        ActionRow {
            icon: "󰆏"; label: sys.tr("Скопировать путь")
            onTriggered: {
                if (clipboard.running) return;
                clipboard.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", view.paths.join("\n")];
                clipboard.running = true;
            }
        }
        ActionRow { icon: "󰉋"; label: sys.tr("Открыть папку"); onTriggered: view.openDetached(["xdg-open", view.path.substring(0, view.path.lastIndexOf('/')) || "/"]) }
        ActionRow {
            icon: "󰇮"; label: sys.tr("Прикрепить к письму")
            onTriggered: { var args = ["xdg-email"]; for (var i = 0; i < view.paths.length; ++i) args.push("--attach", view.paths[i]); view.openDetached(args); }
        }
        ActionRow { visible: view.isImage; icon: "󰋩"; label: sys.tr("Сжать изображение в WebP"); available: !view.busy; onTriggered: view.run("compress") }
        ActionRow { visible: view.isArchive; icon: "󰗄"; label: sys.tr("Извлечь в новую папку"); available: !view.busy; onTriggered: view.run("extract") }
        Text {
            Layout.fillWidth: true; visible: view.busy || view.result.length > 0
            text: view.busy ? sys.tr("Выполняется…") : view.result
            color: sys.colMuted; wrapMode: Text.WrapAnywhere
            font { family: sys.fontFam; pixelSize: 10 }
        }
    }
}
