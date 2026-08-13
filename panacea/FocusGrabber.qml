import QtQuick

// Забирает клавиатурный фокус для поля, которое только что появилось.
//
// Слой получает клавиатуру не в первом кадре: пока композитор её не отдал,
// forceActiveFocus() молча ничего не делает, и первые нажатия улетают в
// никуда — панель открывалась быстрее, чем к ней приходил фокус. Поэтому
// повторяем каждый кадр, пока фокус не возьмётся.
//
// Ставится рядом с полем и запускается сам:
//
//     FocusGrabber { target: input }
//
// Цель может быть и вычисляемой — обычный биндинг, он пересчитается:
//
//     FocusGrabber { target: view.sys.vaultUnlocked ? search : pw }
Timer {
    id: grab

    property Item target: null
    // полсекунды при 60 Гц. Дальше ждать нечего: если фокуса до сих пор нет,
    // его держит кто-то другой, и отбирать силой было бы неверно
    property int maxTries: 30

    property int tries: 0

    interval: 16
    repeat: true
    triggeredOnStart: true
    running: true

    onTriggered: {
        var t = grab.target;
        if (!t || t.activeFocus || grab.tries++ > grab.maxTries) {
            grab.stop();
            return;
        }
        // Невидимой цели фокус не даётся — ждём, пока покажется, но счётчик
        // всё равно идёт: висеть тут вечно этот таймер не должен.
        if (t.visible) t.forceActiveFocus();
    }
}
