import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// System. Слева от характеристик машины стоит живой опрос: память, нагрузка,
// температура и число процессов. Опрашиваем раз в две секунды одной командой
// — отдельные процессы на каждую строку стоили бы дороже самих данных.
ColumnLayout {
    id: page

    property var sys

    property string osName: ""
    property string kernel: ""
    property string wm: ""
    property string cpuName: ""
    property string gpuName: ""
    property string host: ""
    property string uptime: ""

    // живые показатели
    property real memUsed: 0      // ГиБ
    property real memTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property real load1: 0
    property int  procs: 0
    property real tempCpu: -1
    property real tempGpu: -1
    property real diskUsed: 0
    property real diskTotal: 0
    property real selfMb: 0       // сколько занимает сама оболочка, МиБ

    function stepName(st) {
        return st === "download"   ? page.sys.tr("скачивание")
             : st === "selfupdate" ? page.sys.tr("обновление обновлятора")
             : st === "backup"   ? page.sys.tr("сохранение настроек")
             : st === "install"  ? page.sys.tr("установка")
             : st === "restore"  ? page.sys.tr("возврат настроек")
             : st === "restart"  ? page.sys.tr("перезапуск")
             : "";
    }

    // кнопка сброса взведена и ждёт подтверждения
    property bool armed: false
    Timer { id: disarm; interval: 4000; onTriggered: page.armed = false }

    Layout.fillWidth: true
    spacing: 12

    Component.onCompleted: { pInfo.running = true; pLive.running = true; }

    Process {
        id: pInfo
        command: ["sh", "-c",
            "printf '%s\\n' \"$(. /etc/os-release 2>/dev/null; echo $PRETTY_NAME)\" " +
            "\"$(uname -r)\" \"${XDG_CURRENT_DESKTOP:-Hyprland} $(hyprctl version -j 2>/dev/null | sed -n 's/.*\"tag\": *\"\\([^\"]*\\)\".*/\\1/p')\" " +
            "\"$(sed -n 's/^model name[ \\t]*: //p' /proc/cpuinfo | head -1)\" " +
            "\"$(lspci 2>/dev/null | sed -n 's/.*VGA compatible controller: //p' | head -1)\" " +
            "\"$(cat /etc/hostname 2>/dev/null)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var a = text.split("\n");
                page.osName  = (a[0] || "").trim();
                page.kernel  = (a[1] || "").trim();
                page.wm      = (a[2] || "").trim();
                page.cpuName = (a[3] || "").trim();
                page.gpuName = (a[4] || "").trim();
                page.host    = (a[5] || "").trim();
            }
        }
    }

    // Температуру берём из hwmon по имени чипа, а не из thermal_zone:
    // на этой машине единственная зона — acpitz, и она показывает шесть
    // градусов. Из hwmon же понятно, чей это датчик, и его можно подписать.
    Process {
        id: pLive
        command: ["sh", "-c",
            // память | подкачка | загрузка | процессы | ЦП | видео | диск | аптайм | сама оболочка
            "free -k | awk '/^Mem:/{printf \"%s %s|\", $3, $2} /^Swap:/{printf \"%s %s|\", $3, $2}'; " +
            "awk '{printf \"%s|\", $1}' /proc/loadavg; " +
            "ls -d /proc/[0-9]* | wc -l | tr -d '\\n'; printf '|'; " +
            "for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name 2>/dev/null); " +
            "case $n in k10temp|coretemp|zenpower|cpu_thermal|acpitz_cpu) " +
            "cat $h/temp1_input 2>/dev/null | tr -d '\\n'; break;; esac; done; printf '|'; " +
            // Видео: сперва hwmon, как у процессора. Проприетарный драйвер
            // Nvidia датчик туда не всегда выставляет, поэтому если пусто —
            // спрашиваем nvidia-smi. Он отдаёт градусы целым числом, а hwmon
            // — тысячные доли, поэтому домножаем.
            "gpu=''; for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name 2>/dev/null); " +
            "case $n in amdgpu|nouveau|radeon|i915|nvidia) " +
            "gpu=$(cat $h/temp1_input 2>/dev/null); break;; esac; done; " +
            "if [ -z \"$gpu\" ] && command -v nvidia-smi >/dev/null 2>&1; then " +
            "c=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1); " +
            "[ -n \"$c\" ] && gpu=$((c * 1000)); fi; " +
            "printf '%s|' \"$gpu\"; " +
            "df -k --output=used,size / | tail -1 | tr -s ' ' | sed 's/^ //' | tr -d '\\n'; printf '|'; " +
            "uptime -p | tr -d '\\n'; printf '|'; " +
            // сама оболочка: sh запущен из неё, поэтому её PID — это PPID
            "awk '/VmRSS/{printf \"%s\", $2}' /proc/$PPID/status; printf '@'"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Сборщик копит вывод всех запусков подряд, поэтому берём
                // последнюю законченную запись, а не начало текста: без
                // этого показания навсегда оставались снимком первого опроса.
                var recs = text.split("@").filter(r => r.indexOf("|") > 0);
                if (!recs.length) return;
                var a = recs[recs.length - 1].trim().split("|");
                var mem = (a[0] || "").trim().split(/\s+/);
                var swp = (a[1] || "").trim().split(/\s+/);
                var dsk = (a[6] || "").trim().split(/\s+/);
                page.memUsed  = (+mem[0] || 0) / 1048576;
                page.memTotal = (+mem[1] || 0) / 1048576;
                page.swapUsed  = (+swp[0] || 0) / 1048576;
                page.swapTotal = (+swp[1] || 0) / 1048576;
                page.load1  = +a[2] || 0;
                page.procs  = +a[3] || 0;
                // датчики отдают тысячные доли градуса
                page.tempCpu = (+a[4] > 0) ? (+a[4] / 1000) : -1;
                page.tempGpu = (+a[5] > 0) ? (+a[5] / 1000) : -1;
                page.diskUsed  = (+dsk[0] || 0) / 1048576;
                page.diskTotal = (+dsk[1] || 0) / 1048576;
                page.uptime = (a[7] || "").trim();
                page.selfMb = (+a[8] || 0) / 1024;
            }
        }
    }

    // Опрос перезапускаем через сброс: присваивание running = true, когда
    // процесс ещё не отметился завершённым, ничего не делает — показания
    // замирали на первом снимке.
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: { pLive.running = false; pLive.running = true; }
    }

    Process { id: pOpen; property string url: ""; command: ["xdg-open", pOpen.url] }

    // ------------------------------------------------------------- автор
    // Ссылка стоит первой и во всю ширину: это лицо страницы, а не сноска.
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 64
        radius: 18
        color: ghMa.containsMouse
               ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.10)
               : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.045)
        Behavior on color { ColorAnimation { duration: page.sys.animFade } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 14

            Text {
                text: String.fromCodePoint(0xF02A4)   // логотип GitHub
                color: page.sys.colFg
                font { family: page.sys.fontFam; pixelSize: 26 }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: "github.com/EnsixD"
                    color: page.sys.colFg
                    font { family: page.sys.fontDisplay; pixelSize: page.sys.fontSize + 1 }
                }
                Text {
                    text: page.sys.tr("Автор оболочки — профиль на GitHub")
                    color: page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
            }
            Text {
                text: String.fromCodePoint(0xF0327)   // стрелка наружу
                color: page.sys.colMuted
                font { family: page.sys.fontFam; pixelSize: page.sys.fontSize }
            }
        }

        MouseArea {
            id: ghMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { pOpen.url = "https://github.com/EnsixD"; pOpen.running = true; }
        }
    }

    // ------------------------------------------------------------- обновление
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Версия") }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: page.sys.updBusy
                          ? page.sys.tr("Обновление…") + " " + page.stepName(page.sys.updStep)
                          : page.sys.updChecking ? page.sys.tr("Проверка…")
                          : page.sys.updateAvailable ? page.sys.tr("Доступна новая версия")
                          : page.sys.updStatus === "current" ? page.sys.tr("Установлена последняя версия")
                          : page.sys.updStatus === "offline" ? page.sys.tr("Нет связи с GitHub")
                          : page.sys.updStatus === "unknown" ? page.sys.tr("Версия неизвестна: ставили не установщиком")
                          : page.sys.tr("Проверка…")
                    color: page.sys.updateAvailable ? page.sys.colOn : page.sys.colFg
                    wrapMode: Text.WordWrap
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 1 }
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: page.sys.updError.length ? page.sys.updErrorText
                        : page.sys.updateAvailable ? page.sys.updSubject
                        : "Panacea " + page.sys.version
                          + (page.sys.updCurrent.length
                             ? " · " + page.sys.tr("сборка") + " " + page.sys.updCurrent.substring(0, 7) : "")
                    color: page.sys.updError.length ? page.sys.colCrit : page.sys.colMuted
                    wrapMode: Text.WordWrap
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
            }

            // Проверить · Обновить. Вторая появляется только когда есть что
            // ставить: кнопка, которая иногда ничего не делает, хуже её отсутствия.
            Rectangle {
                // Ширина по содержимому, но не уже прежней: надпись задана числом
                // только на глаз, и на другом языке или крупном шрифте она вылезала
                // за края плашки.
                Layout.preferredWidth: Math.max(104, checkRow.implicitWidth + 24)
                Layout.preferredHeight: 32
                radius: 10
                visible: !page.sys.updBusy
                color: checkMa.containsMouse
                       ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.14)
                       : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.06)
                Behavior on color { ColorAnimation { duration: page.sys.animFade } }

                // Пока идёт проверка — вместо надписи крутится стрелка.
                // Проверка занимает секунду-другую, и всё это время кнопка
                // обязана показывать, что её нажатие дошло: если версия
                // окажется прежней, в карточке больше ничего не изменится, и
                // без крутилки нажатие выглядело бы проигнорированным.
                RowLayout {
                    id: checkRow
                    anchors.centerIn: parent
                    spacing: 6

                    Glyph {
                        id: checkSpin
                        visible: page.sys.updChecking
                        glyph: String.fromCodePoint(0xF0450)   // md-refresh
                        color: page.sys.colOn
                        fontFam: page.sys.fontFam
                        size: 13

                        RotationAnimator {
                            target: checkSpin
                            running: page.sys.updChecking
                            from: 0; to: 360
                            duration: 900
                            loops: Animation.Infinite
                        }
                        // Оборвали на полпути — возвращаем в исходное
                        // положение, иначе значок замирал под случайным углом.
                        onVisibleChanged: if (!visible) checkSpin.rotation = 0
                    }

                    Text {
                        text: page.sys.updChecking ? page.sys.tr("Проверка…")
                                                   : page.sys.tr("Проверить")
                        color: page.sys.updChecking ? page.sys.colFg : page.sys.colMuted
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
                    }
                }
                MouseArea {
                    id: checkMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !page.sys.updChecking
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.sys.checkUpdate()
                }
            }

            Rectangle {
                // Ширина по содержимому, но не уже прежней: надпись задана числом
                // только на глаз, и на другом языке или крупном шрифте она вылезала
                // за края плашки.
                Layout.preferredWidth: Math.max(120, updRow.implicitWidth + 24)
                Layout.preferredHeight: 32
                radius: 10
                visible: page.sys.updateAvailable || page.sys.updBusy
                opacity: page.sys.updBusy ? 0.6 : 1
                color: updMa.containsMouse && !page.sys.updBusy
                       ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.34)
                       : Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.22)
                border.width: 1
                border.color: page.sys.colOn
                Behavior on color { ColorAnimation { duration: page.sys.animFade } }

                Text {
                    anchors.centerIn: parent
                    text: page.sys.updBusy ? page.sys.tr("Идёт…") : page.sys.tr("Обновить")
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3; bold: true }
                }
                MouseArea {
                    id: updMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !page.sys.updBusy
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.sys.applyUpdate()
                }
            }
        }

        // Ход обновления: полоса и этапы.
        //
        // Байты не считаем — update.sh их не знает. Зато знает свои этапы, и их
        // ровно столько, сколько есть: полоса идёт по ним, а не по времени.
        // Ползти вслепую по таймеру было бы враньём — на медленной сети она
        // добралась бы до конца задолго до самого обновления.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            visible: page.sys.updBusy
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 6
                radius: 3
                color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.10)

                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: parent.width * page.sys.updStepPercent / 100
                    color: page.sys.colOn
                    Behavior on width {
                        NumberAnimation { duration: page.sys.animMs; easing.type: Easing.OutQuint }
                    }
                }
            }

            // Этапы подписью, а не только процентом: «скачивание» и «установка»
            // объясняют паузу, а «73%» — нет.
            RowLayout {
                    id: updRow
                Layout.fillWidth: true
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: page.stepName(page.sys.updStep)
                    color: page.sys.colMuted
                    elide: Text.ElideRight
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
                Text {
                    text: page.sys.updStepPercent + "%"
                    color: page.sys.colMuted
                    font { family: page.sys.fontFam; pixelSize: page.sys.fontSize - 4 }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Настройки, сочетания клавиш и обои остаются на месте: перед установкой они уносятся в сторону и возвращаются после.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }


    // ------------------------------------------------------------- нагрузка
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Сейчас") }

        component Meter: ColumnLayout {
            property string label: ""
            property string value: ""
            property real frac: 0
            property color tint: page.sys.colOn

            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: label
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                }
                Text {
                    text: value
                    color: page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: 3
                color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.10)
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, frac))
                    height: parent.height
                    radius: parent.radius
                    color: tint
                    Behavior on width { NumberAnimation { duration: page.sys.animFade } }
                }
            }
        }

        // Показания системные, а не оболочкины: в них попадают браузер,
        // мессенджеры и всё остальное. Сколько занимает сама Panacea —
        // отдельной строкой ниже, иначе шесть гигабайт читаются как её вина.
        Meter {
            label: page.sys.tr("Оперативная память системы")
            value: page.memUsed.toFixed(1) + " / " + page.memTotal.toFixed(1) + " GiB"
            frac: page.memTotal > 0 ? page.memUsed / page.memTotal : 0
        }

        Meter {
            visible: page.swapTotal > 0
            label: page.sys.tr("Подкачка")
            value: page.swapUsed.toFixed(1) + " / " + page.swapTotal.toFixed(1) + " GiB"
            frac: page.swapTotal > 0 ? page.swapUsed / page.swapTotal : 0
        }

        Meter {
            label: page.sys.tr("Диск /")
            value: page.diskUsed.toFixed(0) + " / " + page.diskTotal.toFixed(0) + " GiB"
            frac: page.diskTotal > 0 ? page.diskUsed / page.diskTotal : 0
        }

        Meter {
            visible: page.tempCpu >= 0
            label: page.sys.tr("Температура процессора")
            value: page.tempCpu.toFixed(0) + " °C"
            // шкала до 100 °C: выше 80 столбик становится тревожным
            frac: page.tempCpu / 100
            tint: page.tempCpu >= 80 ? page.sys.colCrit : page.sys.colOn
        }

        Meter {
            visible: page.tempGpu >= 0
            label: page.sys.tr("Температура видео")
            value: page.tempGpu.toFixed(0) + " °C"
            frac: page.tempGpu / 100
            tint: page.tempGpu >= 85 ? page.sys.colCrit : page.sys.colOn
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 18

            Text {
                text: page.sys.tr("Нагрузка") + ": " + page.load1.toFixed(2)
                color: page.sys.colMuted
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }
            Text {
                text: "Panacea: " + page.selfMb.toFixed(0) + " MiB"
                color: page.sys.colMuted
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }
            Text {
                text: page.sys.tr("Процессов") + ": " + page.procs
                color: page.sys.colMuted
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }
            Item { Layout.fillWidth: true }
        }
    }

    // ------------------------------------------------------------- машина
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Машина") }

        component Fact: RowLayout {
            property string k: ""
            property string v: ""

            Layout.fillWidth: true
            visible: v.length > 0
            spacing: 12

            Text {
                text: k
                color: page.sys.colMuted
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: v
                color: page.sys.colFg
                elide: Text.ElideRight
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }
        }

        Fact { k: page.sys.tr("Система");    v: page.osName }
        Fact { k: page.sys.tr("Ядро");       v: page.kernel }
        Fact { k: page.sys.tr("Композитор"); v: page.wm }
        Fact { k: page.sys.tr("Процессор");  v: page.cpuName }
        Fact { k: page.sys.tr("Видео");      v: page.gpuName }
        Fact { k: page.sys.tr("Имя машины"); v: page.host }
        Fact { k: page.sys.tr("Аптайм");     v: page.uptime }
        Fact { k: page.sys.tr("Оболочка");   v: "Panacea " + page.sys.version }
    }

    // ------------------------------------------------------------- сброс
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Сброс") }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: page.armed
                      ? page.sys.tr("Нажмите ещё раз — все настройки вернутся к заводским.")
                      : page.sys.tr("Вернуть все настройки к заводским. Сочетания клавиш останутся как есть.")
                color: page.armed ? page.sys.colCrit : page.sys.colMuted
                wrapMode: Text.WordWrap
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
            }

            Rectangle {
                // Ширина по надписи, но не уже прежней: «Точно сбросить» и
                // «Сбросить всё» разной длины, а по-английски обе длиннее —
                // на глаз подобранные 140 их уже не вмещали.
                Layout.preferredWidth: Math.max(140, resetLabel.implicitWidth + 24)
                Layout.preferredHeight: 32
                radius: 10
                color: page.armed
                       ? Qt.rgba(page.sys.colCrit.r, page.sys.colCrit.g, page.sys.colCrit.b,
                                 resetMa.containsMouse ? 0.40 : 0.26)
                       : (resetMa.containsMouse
                          ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.14)
                          : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.06))
                border.width: page.armed ? 1 : 0
                border.color: page.sys.colCrit
                Behavior on color { ColorAnimation { duration: page.sys.animFade } }

                Text {
                    id: resetLabel
                    anchors.centerIn: parent
                    text: page.armed ? page.sys.tr("Точно сбросить") : page.sys.tr("Сбросить всё")
                    color: page.armed ? page.sys.colFg : page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
                }

                MouseArea {
                    id: resetMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // Сброс в два нажатия: одно случайное движение мышью не
                    // должно стирать всю настроенную оболочку.
                    onClicked: {
                        if (page.armed) { page.sys.resetCfg(); page.armed = false; }
                        else { page.armed = true; disarm.restart(); }
                    }
                }
            }
        }
    }

}
