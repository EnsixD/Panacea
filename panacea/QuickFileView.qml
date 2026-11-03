import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io

ColumnLayout {
    id: view
    property var sys
    property bool busy: false
    property string result: ""
    readonly property var paths: sys.quickFilePaths
    readonly property string path: paths.length ? paths[0] : ""
    readonly property string filename: path.split('/').pop()
    readonly property string lower: filename.toLowerCase()
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
    function run(op) {
        if (busy) return;
        busy = true; result = "";
        action.command = ["python3", sys.scriptDir + "/quick-file.py", op].concat(paths);
        action.running = true;
    }
    ColumnLayout {
        id: content
        Layout.fillWidth: true
        Text { text: view.sys.tr("Быстрые действия"); color: view.sys.colFg; font { family: view.sys.fontFam; pixelSize: 16; bold: true } }
        Text { Layout.fillWidth: true; text: view.paths.length === 1 ? view.filename : view.paths.length + " " + view.sys.tr("файлов"); elide: Text.ElideMiddle; color: view.sys.colMuted; font { family: view.sys.fontFam; pixelSize: 12 } }
        Button {
            Layout.fillWidth: true; text: view.sys.tr("Скопировать путь")
            onClicked: { view.sys.runDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", view.paths.join("\n")]); view.result = view.sys.tr("Путь скопирован"); }
        }
        Button {
            Layout.fillWidth: true; text: view.sys.tr("Открыть папку")
            onClicked: view.sys.runDetached(["xdg-open", view.path.substring(0, view.path.lastIndexOf('/')) || "/"])
        }
        Button {
            Layout.fillWidth: true; text: view.sys.tr("Прикрепить к письму")
            onClicked: {
                var args = ["xdg-email"];
                for (var i = 0; i < view.paths.length; ++i) args.push("--attach", view.paths[i]);
                view.sys.runDetached(args);
            }
        }
        Button {
            Layout.fillWidth: true; visible: view.isImage; enabled: !view.busy
            text: view.sys.tr("Сжать изображение в WebP")
            onClicked: view.run("compress")
        }
        Button {
            Layout.fillWidth: true; visible: view.isArchive; enabled: !view.busy
            text: view.sys.tr("Извлечь в новую папку")
            onClicked: view.run("extract")
        }
        Text {
            Layout.fillWidth: true; visible: view.busy || view.result.length > 0
            text: view.busy ? view.sys.tr("Выполняется…") : view.result
            color: view.sys.colMuted; wrapMode: Text.WrapAnywhere
            font { family: view.sys.fontFam; pixelSize: 10 }
        }
    }
}
