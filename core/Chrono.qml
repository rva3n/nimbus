pragma Singleton
import QtQuick
import Quickshell

// Состояние таймера/секундомера — наполняется в волне 2 (страницы «Таймеры»).
Singleton {
    property bool timerRunning: false
    property int timerSeconds: 0
    property bool stopwatchRunning: false
    property int stopwatchSeconds: 0
}
