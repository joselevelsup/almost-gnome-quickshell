import QtQuick
import ".."

// GNOME top bar clock ("Nov 5  19:09", options in Settings); opens the calendar.
BarButton {
    id: clock
    active: PopupManager.current === "calendar"

    Text {
        text: Qt.formatDateTime(Clock.now, Settings.barFormat)
        font.family: Theme.fontFamily
        font.pixelSize: 15
        font.weight: Font.Bold
        color: Theme.fg
    }

    onClicked: PopupManager.open("calendar")
}
