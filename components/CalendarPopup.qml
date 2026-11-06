import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."

// Combined calendar + notifications panel, like the one GNOME Shell opens
// when clicking the clock.
PopupCard {
    id: popup
    popupName: "calendar"
    align: "center"
    cardWidth: 300

    Text {
        width: parent.width
        text: {
            var now = Clock.now
            var wd = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            var d = ["January", "February", "March", "April", "May", "June",
                     "July", "August", "September", "October", "November", "December"]
            return wd[now.getDay()] + ", " + d[now.getMonth()] + " " + now.getDate()
        }
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.weight: Font.Bold
        color: Theme.fg
        horizontalAlignment: Text.AlignHCenter
    }

    RowLayout {
        width: parent.width
        spacing: 4

        BarButton {
            spacing: 0
            SymbolicIcon { name: "pan-start-symbolic"; size: 12 }
            onClicked: cal.prevMonth()
        }
        Text {
            Layout.fillWidth: true
            text: cal.monthLabel
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: Theme.fg
            horizontalAlignment: Text.AlignHCenter
        }
        BarButton {
            spacing: 0
            SymbolicIcon { name: "pan-end-symbolic"; size: 12 }
            onClicked: cal.nextMonth()
        }
    }

    Rectangle {
        width: parent.width
        height: 224
        color: "transparent"
        Calendar { id: cal; anchors.fill: parent }
    }

    MediaPlayer { width: parent.width }

    Rectangle { width: parent.width; height: 1; color: Theme.border }

    RowLayout {
        width: parent.width
        Text {
            text: "Notifications"
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Theme.fg
            Layout.fillWidth: true
        }
        Text {
            visible: Notifications.history.length > 0
            text: "Clear"
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: 11
            MouseArea { anchors.fill: parent; onClicked: Notifications.clear() }
        }
    }

    Text {
        width: parent.width
        visible: Notifications.history.length === 0
        text: "No Notifications"
        color: Theme.fgDim
        font.family: Theme.fontFamily
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
    }

    Item {
        width: parent.width
        height: Math.min(280, notifList.contentHeight)
        visible: Notifications.history.length > 0

        ListView {
            id: notifList
            anchors.fill: parent
            spacing: 6
            clip: true
            model: Notifications.history
            delegate: NotificationRow {
                width: notifList.width
                appName: modelData.appName
                summary: modelData.summary
                body: modelData.body || ""
                appIcon: modelData.appIcon || ""
                time: modelData.time
                onDismissRequested: {
                    var arr = Notifications.history.slice()
                    arr.splice(index, 1)
                    Notifications.history = arr
                }
            }
        }
    }
}
