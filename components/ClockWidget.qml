import QtQuick
import ".."

// GNOME top bar clock ("Nov 5  19:09", options in Settings); opens the calendar.
BarButton {
    id: clock
    active: PopupManager.current === "calendar"

    readonly property var o: Settings.options
    readonly property string fmt: (o.clockWeekday ? "ddd " : "") + "MMM d  "
        + (o.clock24h ? "HH:mm" : "h:mm") + (o.clockSeconds ? ":ss" : "") + (o.clock24h ? "" : " AP")

    Text {
        text: Qt.formatDateTime(Clock.now, clock.fmt)
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.weight: Font.Bold
        color: Theme.fg
    }

    onClicked: PopupManager.open("calendar")
}
