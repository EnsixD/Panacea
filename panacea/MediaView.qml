import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtMultimedia
import Quickshell
import Quickshell.Io

// Медиаплеер пилюли: видео, гифки и картинки в одном окне.
//
// Видео можно обрезать по началу и концу и сохранить кусок,
// картинку — выделить область и сохранить кроп. Всё режет ffmpeg
// через scripts/media.sh, интерфейс только собирает параметры.
FocusScope {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    readonly property string path: sys.mediaPath
    readonly property string fileName: String(path).split("/").pop()
    readonly property string ext: String(fileName).split(".").pop().toLowerCase()
    readonly property bool isVideo: ["mp4", "mkv", "webm", "mov", "avi", "m4v", "wmv", "flv",
                                     "mpg", "mpeg", "ts"].indexOf(ext) >= 0
    readonly property bool isAnimated: ["gif", "webp", "apng"].indexOf(ext) >= 0

    // натуральный размер и длительность — от ffprobe
    property real srcW: 0
    property real srcH: 0
    property real srcDur: 0

    // режим выделения области; общий с пилюлей, чтобы им можно было
    // управлять и снаружи
    property bool cropMode: sys.mediaCrop
    property string saveDir: ""        // "" — рядом с оригиналом
    property string savedPath: ""
    property string busyText: ""

    // границы обрезки видео, секунды
    property real trimIn: 0
    property real trimOut: 0

    focus: true
    Component.onCompleted: { forceActiveFocus(); probe(); }

    readonly property string script: sys.scriptDir + "/media.sh"

    Process {
        id: pProbe
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p.length < 3) return;
                view.srcDur = parseFloat(p[0]) || 0;
                view.srcW = parseInt(p[1]) || 0;
                view.srcH = parseInt(p[2]) || 0;
                if (view.isVideo) view.trimOut = view.srcDur;
            }
        }
    }
    function probe() {
        pProbe.command = ["sh", "-c", view.script + " probe \"$1\"", "_", view.path];
        pProbe.running = false;
        pProbe.running = true;
    }

    Process {
        id: pSave
        stdout: SplitParser {
            onRead: line => {
                var t = line.trim();
                if (t.length) view.savedPath = t;
            }
        }
        onRunningChanged: {
            if (running) return;
            view.busyText = "";
            savedClear.restart();
        }
    }
    Timer { id: savedClear; interval: 6000; onTriggered: view.savedPath = "" }

    Process { id: pOpenExt }
    function openExternally() {
        pOpenExt.command = ["sh", "-c", view.sys.scriptDir + "/files.sh open \"$1\"", "_", view.path];
        pOpenExt.running = true;
    }

    function fmt(sec) {
        if (!isFinite(sec) || sec < 0) sec = 0;
        var s = Math.floor(sec);
        var m = Math.floor(s / 60), x = s % 60;
        return m + ":" + (x < 10 ? "0" : "") + x;
    }

    // ------------------------------------------------------------- сохранение
    function saveCut() {
        if (!view.isVideo) return;
        if (view.trimOut - view.trimIn < 0.2) return;
        view.busyText = view.sys.tr("Режу…");
        var r = view.cropRegion();
        pSave.command = r
            ? ["sh", "-c",
               view.script + " cut \"$1\" \"$2\" \"$3\" \"$4\" \"$5\" \"$6\" \"$7\" \"$8\"", "_",
               view.path, view.trimIn.toFixed(2), view.trimOut.toFixed(2), view.saveDir,
               String(r.x), String(r.y), String(r.w), String(r.h)]
            : ["sh", "-c",
               view.script + " cut \"$1\" \"$2\" \"$3\" \"$4\"", "_",
               view.path, view.trimIn.toFixed(2), view.trimOut.toFixed(2), view.saveDir];
        pSave.running = true;
    }

    // Выделение на экране -> пиксели оригинала. Возвращает null, если
    // выделять нечего: числа для ffmpeg должны быть целыми и в пределах кадра.
    function cropRegion() {
        if (!view.cropMode || !cropRect.valid) return null;
        if (shot.paintedWidth <= 0 || view.srcW <= 0) return null;

        var k = view.srcW / shot.paintedWidth;
        var x = Math.round((cropRect.selX - shot.offX) * k);
        var y = Math.round((cropRect.selY - shot.offY) * k);
        var w = Math.round(cropRect.selW * k);
        var h = Math.round(cropRect.selH * k);

        x = Math.max(0, Math.min(x, view.srcW - 2));
        y = Math.max(0, Math.min(y, view.srcH - 2));
        if (x + w > view.srcW) w = view.srcW - x;
        if (y + h > view.srcH) h = view.srcH - y;
        // h264 не любит нечётные размеры
        w = w - (w % 2); h = h - (h % 2);
        if (w < 8 || h < 8) return null;
        return { x: x, y: y, w: w, h: h };
    }

    function saveCrop() {
        if (view.isVideo) return;
        var r = view.cropRegion();
        if (!r) return;

        view.busyText = view.sys.tr("Режу…");
        pSave.command = ["sh", "-c",
            view.script + " crop \"$1\" \"$2\" \"$3\" \"$4\" \"$5\" \"$6\"", "_",
            view.path, String(r.x), String(r.y), String(r.w), String(r.h), view.saveDir];
        pSave.running = true;
    }

    // ---------------------------------------------------------------- клавиши
    Keys.onEscapePressed: {
        if (view.cropMode) { view.sys.mediaCrop = false; return; }
        view.sys.collapse();
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space && view.isVideo) {
            player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left && view.isVideo) {
            player.position = Math.max(0, player.position - 5000);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right && view.isVideo) {
            player.position = Math.min(player.duration, player.position + 5000);
            event.accepted = true;
        } else if (event.key === Qt.Key_C) {
            view.sys.mediaCropToggle();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            view.isVideo ? view.saveCut() : view.saveCrop();
            event.accepted = true;
        }
    }

    // ------------------------------------------------------------- кусочки UI
    component Chip: Rectangle {
        property string label: ""
        property bool active: false
        signal picked()

        implicitWidth: cText.implicitWidth + 22
        implicitHeight: 30
        radius: 15
        color: active ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.18)
             : (cMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
        border.color: active ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g,
                                       view.sys.colOn.b, 0.45)
                             : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 150 } }

        Text {
            id: cText
            anchors.centerIn: parent
            text: parent.label
            color: parent.active ? view.sys.colFg : view.sys.colMuted
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; bold: parent.active }
        }
        MouseArea {
            id: cMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.picked()
        }
    }

    component IconButton: Rectangle {
        property string glyph: ""
        property color tint: view.sys.colFg
        property bool filled: false
        signal pressedAction()

        implicitWidth: 40
        implicitHeight: 40
        radius: 20
        color: filled ? Qt.rgba(tint.r, tint.g, tint.b, ibMa.containsMouse ? 0.34 : 0.22)
                      : (ibMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))
        border.color: view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 140 } }
        scale: ibMa.pressed ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

        Glyph {
            anchors.fill: parent
            glyph: parent.glyph
            color: parent.filled ? parent.tint : view.sys.colFg
            fontFam: view.sys.fontFam
            size: view.sys.iconSize
        }
        MouseArea {
            id: ibMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.pressedAction()
        }
    }

    // ------------------------------------------------------------------- вид
    ColumnLayout {
        id: col
        width: parent.width
        spacing: 12

        // ------------------------------------------------------------ шапка
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Glyph {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                glyph: String.fromCodePoint(view.isVideo ? 0xF022B
                                          : view.isAnimated ? 0xF0210 : 0xF021F)
                color: view.sys.colOn
                fontFam: view.sys.fontFam
                size: view.sys.iconSize + 3
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: view.fileName
                    color: view.sys.colFg
                    elide: Text.ElideMiddle
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 2; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    text: view.busyText.length ? view.busyText
                        : view.savedPath.length ? view.sys.tr("Сохранено: ") + view.savedPath
                        : (view.srcW > 0 ? view.srcW + "×" + view.srcH : "")
                          + (view.isVideo && view.srcDur > 0 ? "  ·  " + view.fmt(view.srcDur) : "")
                    color: view.savedPath.length ? view.sys.colOk : view.sys.colMuted
                    elide: Text.ElideMiddle
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
            }

            // выделение области — и для картинок, и для видео
            Rectangle {
                Layout.preferredWidth: cropText.implicitWidth + 46
                Layout.preferredHeight: 40
                radius: 14
                color: view.cropMode
                       ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.24)
                       : (cropMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))
                border.color: view.cropMode
                              ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.5)
                              : view.sys.colLine
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Glyph {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        glyph: String.fromCodePoint(0xF0211)   // md-crop
                        color: view.cropMode ? view.sys.colOn : view.sys.colFg
                        fontFam: view.sys.fontFam
                        size: view.sys.iconSize - 1
                    }
                    Text {
                        id: cropText
                        text: view.sys.tr("Кроп")
                        color: view.sys.colFg
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2; bold: true }
                    }
                }
                MouseArea {
                    id: cropMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        view.sys.mediaCropToggle();
                        if (!view.sys.mediaCrop) { cropRect.selW = 0; cropRect.selH = 0; }
                    }
                }
            }
            IconButton {
                glyph: String.fromCodePoint(0xF03CB)      // md-open_in_app
                onPressedAction: { view.openExternally(); view.sys.collapse(); }
            }
            IconButton {
                glyph: String.fromCodePoint(0xF0156)      // md-close
                onPressedAction: view.sys.collapse()
            }
        }

        // --------------------------------------------------------- полотно
        Rectangle {
            id: stage
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(view.sys.mediaStageH)
            radius: 16
            color: "#000000"
            clip: true

            // ---- картинка или гифка
            AnimatedImage {
                id: shotAnim
                anchors.fill: parent
                visible: !view.isVideo && view.isAnimated
                source: (!view.isVideo && view.isAnimated) ? "file://" + view.path : ""
                fillMode: Image.PreserveAspectFit
                playing: visible
                cache: true
            }
            Image {
                id: shotStill
                anchors.fill: parent
                visible: !view.isVideo && !view.isAnimated
                source: (!view.isVideo && !view.isAnimated) ? "file://" + view.path : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
                smooth: true
                // Декодируем ровно под размер полотна: двойной запас на
                // четырёхтысячных снимках стоил двух секунд чёрного экрана,
                // а на качество кропа не влияет — ffmpeg режет оригинал.
                sourceSize: Qt.size(stage.width, stage.height)
            }

            // Прямоугольник, в котором реально нарисован кадр: у картинки
            // это painted-размер, у видео — contentRect самого VideoOutput.
            QtObject {
                id: shot
                readonly property real paintedWidth:
                    view.isVideo ? vout.contentRect.width
                                 : (view.isAnimated ? shotAnim.paintedWidth
                                                    : shotStill.paintedWidth)
                readonly property real paintedHeight:
                    view.isVideo ? vout.contentRect.height
                                 : (view.isAnimated ? shotAnim.paintedHeight
                                                    : shotStill.paintedHeight)
                readonly property real offX:
                    view.isVideo ? vout.contentRect.x
                                 : (stage.width - paintedWidth) / 2
                readonly property real offY:
                    view.isVideo ? vout.contentRect.y
                                 : (stage.height - paintedHeight) / 2
            }

            // ---- видео
            VideoOutput {
                id: vout
                anchors.fill: parent
                visible: view.isVideo
                fillMode: VideoOutput.PreserveAspectFit
            }

            MediaPlayer {
                id: player
                source: view.isVideo ? "file://" + view.path : ""
                videoOutput: vout
                audioOutput: AudioOutput { id: aout; volume: 0.9 }
                onDurationChanged: {
                    if (duration > 0 && view.trimOut <= 0) view.trimOut = duration / 1000;
                }
                Component.onCompleted: if (view.isVideo) play()
            }

            // клик по видео — пауза/продолжить
            MouseArea {
                anchors.fill: parent
                visible: view.isVideo && !view.cropMode
                onClicked: player.playbackState === MediaPlayer.PlayingState
                           ? player.pause() : player.play()
            }

            // ---- выделение области на картинке
            Item {
                id: cropRect
                anchors.fill: parent
                visible: view.cropMode

                property real selX: 0
                property real selY: 0
                property real selW: 0
                property real selH: 0
                readonly property bool valid: selW > 8 && selH > 8

                // затемняем всё, кроме выделенного
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.55)
                    visible: !cropRect.valid
                }
                Repeater {
                    model: cropRect.valid ? 4 : 0
                    Rectangle {
                        required property int index
                        color: Qt.rgba(0, 0, 0, 0.55)
                        x: index === 0 || index === 1 ? 0
                         : index === 2 ? 0 : cropRect.selX + cropRect.selW
                        y: index === 0 ? 0
                         : index === 1 ? cropRect.selY + cropRect.selH
                         : cropRect.selY
                        width: index < 2 ? cropRect.width
                             : index === 2 ? cropRect.selX
                                           : cropRect.width - cropRect.selX - cropRect.selW
                        height: index === 0 ? cropRect.selY
                              : index === 1 ? cropRect.height - cropRect.selY - cropRect.selH
                                            : cropRect.selH
                    }
                }

                Rectangle {
                    visible: cropRect.valid
                    x: cropRect.selX; y: cropRect.selY
                    width: cropRect.selW; height: cropRect.selH
                    color: "transparent"
                    border.color: view.sys.colOn
                    border.width: 2

                    // уголки: тонкие уголки читаются лучше рамки
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            width: 14; height: 14
                            color: view.sys.colOn
                            radius: 3
                            x: (index % 2 === 0 ? -7 : parent.width - 7)
                            y: (index < 2 ? -7 : parent.height - 7)
                        }
                    }
                }

                // Выделение живёт до тех пор, пока его не сбросят: по нему
                // можно таскать и тянуть за углы, а не рисовать заново.
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: {
                        if (!cropRect.valid) return Qt.CrossCursor;
                        var m = hitTest(mouseX, mouseY);
                        if (m === "move") return Qt.SizeAllCursor;
                        if (m === "nw" || m === "se") return Qt.SizeFDiagCursor;
                        if (m === "ne" || m === "sw") return Qt.SizeBDiagCursor;
                        return Qt.ArrowCursor;
                    }

                    property string mode: ""
                    property real ax: 0
                    property real ay: 0
                    property real ox: 0
                    property real oy: 0

                    // за что взялись в точке (x, y)
                    function hitTest(x, y) {
                        if (!cropRect.valid) return "new";
                        var r = 22;
                        var l = cropRect.selX, t = cropRect.selY;
                        var rr = l + cropRect.selW, b = t + cropRect.selH;
                        if (Math.abs(x - l) < r && Math.abs(y - t) < r) return "nw";
                        if (Math.abs(x - rr) < r && Math.abs(y - t) < r) return "ne";
                        if (Math.abs(x - l) < r && Math.abs(y - b) < r) return "sw";
                        if (Math.abs(x - rr) < r && Math.abs(y - b) < r) return "se";
                        if (x > l && x < rr && y > t && y < b) return "move";
                        return "";
                    }

                    onPressed: mouse => {
                        mode = hitTest(mouse.x, mouse.y);
                        ax = mouse.x; ay = mouse.y;
                        ox = cropRect.selX; oy = cropRect.selY;
                        if (mode === "new") { cropRect.selW = 0; cropRect.selH = 0; }
                    }
                    onDoubleClicked: {
                        // двойной щелчок — начать выделение заново
                        cropRect.selW = 0; cropRect.selH = 0;
                        mode = "";
                    }
                    onPositionChanged: mouse => {
                        if (!pressed || mode.length === 0) return;
                        var maxW = cropRect.width, maxH = cropRect.height;

                        if (mode === "new") {
                            cropRect.selX = Math.max(0, Math.min(ax, mouse.x));
                            cropRect.selY = Math.max(0, Math.min(ay, mouse.y));
                            cropRect.selW = Math.min(Math.abs(mouse.x - ax),
                                                     maxW - cropRect.selX);
                            cropRect.selH = Math.min(Math.abs(mouse.y - ay),
                                                     maxH - cropRect.selY);
                            return;
                        }

                        if (mode === "move") {
                            cropRect.selX = Math.max(0, Math.min(maxW - cropRect.selW,
                                                                 ox + mouse.x - ax));
                            cropRect.selY = Math.max(0, Math.min(maxH - cropRect.selH,
                                                                 oy + mouse.y - ay));
                            return;
                        }

                        // тянем за угол: противоположный остаётся на месте
                        var l = cropRect.selX, t = cropRect.selY;
                        var r = l + cropRect.selW, b = t + cropRect.selH;
                        var mx = Math.max(0, Math.min(maxW, mouse.x));
                        var my = Math.max(0, Math.min(maxH, mouse.y));

                        if (mode === "nw")      { l = Math.min(mx, r - 16); t = Math.min(my, b - 16); }
                        else if (mode === "ne") { r = Math.max(mx, l + 16); t = Math.min(my, b - 16); }
                        else if (mode === "sw") { l = Math.min(mx, r - 16); b = Math.max(my, t + 16); }
                        else if (mode === "se") { r = Math.max(mx, l + 16); b = Math.max(my, t + 16); }

                        cropRect.selX = l; cropRect.selY = t;
                        cropRect.selW = r - l; cropRect.selH = b - t;
                    }
                    onReleased: mode = ""
                }
            }

            // подсказка в режиме выделения
            Rectangle {
                visible: view.cropMode && !cropRect.valid
                z: 5
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                width: hintText.implicitWidth + 24
                height: 32
                radius: 16
                color: Qt.rgba(0.04, 0.04, 0.05, 0.9)
                border.color: view.sys.colLine
                border.width: 1
                Text {
                    id: hintText
                    anchors.centerIn: parent
                    text: view.sys.tr("Выделите область мышью")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
            }
        }

        // ------------------------------------------------- управление видео
        ColumnLayout {
            Layout.fillWidth: true
            visible: view.isVideo
            spacing: 8

            // дорожка с областью обрезки
            Item {
                id: track
                Layout.fillWidth: true
                Layout.preferredHeight: 26

                readonly property real dur: player.duration > 0 ? player.duration / 1000 : view.srcDur
                function xOf(sec) { return dur > 0 ? width * (sec / dur) : 0; }
                function secOf(x)  { return dur > 0 ? Math.max(0, Math.min(dur, dur * x / width)) : 0; }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.12)
                }
                // выбранный кусок
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: track.xOf(view.trimIn)
                    width: Math.max(0, track.xOf(view.trimOut) - track.xOf(view.trimIn))
                    height: 6
                    radius: 3
                    color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.55)
                }
                // проигранное
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: track.xOf(player.position / 1000)
                    height: 6
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.35)
                }
                // головка
                Rectangle {
                    width: 4; height: 20; radius: 2
                    x: track.xOf(player.position / 1000) - 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#ffffff"
                }

                // Маркеры обрезки и головка: одной областью, чтобы понимать,
                // за что именно взялись. Ползунок ведём за курсором, видео
                // перематывается прямо во время перетаскивания.
                Repeater {
                    model: 2
                    Rectangle {
                        required property int index
                        readonly property real sec: index === 0 ? view.trimIn : view.trimOut
                        readonly property bool held: trackMa.grab === (index === 0 ? "in" : "out")

                        width: 14
                        height: 30
                        radius: 5
                        x: Math.max(-7, Math.min(track.width - 7, track.xOf(sec) - 7))
                        anchors.verticalCenter: parent.verticalCenter
                        color: view.sys.colOn
                        border.color: Qt.rgba(0, 0, 0, 0.45)
                        border.width: 1
                        scale: held ? 1.15 : 1.0
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        // две насечки — сразу видно, что это ручка
                        Column {
                            anchors.centerIn: parent
                            spacing: 3
                            Repeater {
                                model: 2
                                Rectangle {
                                    width: 6; height: 1.5; radius: 1
                                    color: Qt.rgba(0, 0, 0, 0.5)
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    id: trackMa
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: grab.length ? Qt.SizeHorCursor : Qt.PointingHandCursor

                    // за что взялись: "in" | "out" | "seek"
                    property string grab: ""

                    function localX(mx) { return Math.max(0, Math.min(track.width, mx - 8)); }

                    onPressed: mouse => {
                        var x = localX(mouse.x);
                        var dIn = Math.abs(x - track.xOf(view.trimIn));
                        var dOut = Math.abs(x - track.xOf(view.trimOut));
                        // ближняя ручка в пределах 14 px перетягивает, иначе перемотка
                        if (dIn <= 14 && dIn <= dOut) grab = "in";
                        else if (dOut <= 14) grab = "out";
                        else { grab = "seek"; player.position = track.secOf(x) * 1000; }
                    }
                    onPositionChanged: mouse => {
                        if (!pressed || !grab.length) return;
                        var sec = track.secOf(localX(mouse.x));
                        if (grab === "in")
                            view.trimIn = Math.max(0, Math.min(sec, view.trimOut - 0.2));
                        else if (grab === "out")
                            view.trimOut = Math.min(track.dur, Math.max(sec, view.trimIn + 0.2));
                        else
                            player.position = sec * 1000;
                    }
                    onReleased: grab = ""
                    onCanceled: grab = ""
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                IconButton {
                    glyph: String.fromCodePoint(
                               player.playbackState === MediaPlayer.PlayingState ? 0xF03E4 : 0xF040A)
                    tint: view.sys.colOn
                    filled: true
                    onPressedAction: player.playbackState === MediaPlayer.PlayingState
                                     ? player.pause() : player.play()
                }

                Text {
                    text: view.fmt(player.position / 1000) + " / " + view.fmt(track.dur)
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }

                Item { Layout.fillWidth: true }

                Chip {
                    label: view.sys.tr("Начало здесь")
                    onPicked: view.trimIn = Math.min(player.position / 1000, view.trimOut - 0.2)
                }
                Chip {
                    label: view.sys.tr("Конец здесь")
                    onPicked: view.trimOut = Math.max(player.position / 1000, view.trimIn + 0.2)
                }
                Text {
                    text: view.fmt(view.trimIn) + " — " + view.fmt(view.trimOut)
                    color: view.sys.colOn
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; bold: true }
                }
            }
        }

        // ------------------------------------------------------ сохранение
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: view.sys.tr("Куда")
                color: view.sys.colMuted
                font {
                    family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4
                    bold: true; capitalization: Font.AllUppercase; letterSpacing: 1
                }
            }
            Chip {
                label: view.sys.tr("Рядом")
                active: view.saveDir === ""
                onPicked: view.saveDir = ""
            }
            Repeater {
                model: ["~/Videos", "~/Pictures", "~/Desktop"]
                Chip {
                    required property var modelData
                    label: String(modelData)
                    active: view.saveDir === modelData
                    onPicked: view.saveDir = modelData
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredWidth: saveText.implicitWidth + 34
                Layout.preferredHeight: 40
                radius: 14
                enabled: view.isVideo ? (view.trimOut - view.trimIn > 0.2)
                                      : (view.cropMode && cropRect.valid)
                opacity: enabled ? 1 : 0.4
                color: saveMa.containsMouse
                       ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.34)
                       : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                border.color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.5)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 9
                    Glyph {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        glyph: String.fromCodePoint(0xF0193)   // md-content_save
                        color: view.sys.colOn
                        fontFam: view.sys.fontFam
                        size: view.sys.iconSize - 2
                    }
                    Text {
                        id: saveText
                        text: view.isVideo
                              ? (view.cropMode && cropRect.valid
                                 ? view.sys.tr("Сохранить кусок с кропом")
                                 : view.sys.tr("Сохранить кусок"))
                              : view.sys.tr("Сохранить область")
                        color: view.sys.colFg
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2; bold: true }
                    }
                }

                MouseArea {
                    id: saveMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: parent.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.isVideo ? view.saveCut() : view.saveCrop()
                }
            }
        }
    }
}
