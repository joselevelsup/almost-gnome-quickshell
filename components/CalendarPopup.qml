import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."

// Combined notifications + calendar panel, like the one GNOME Shell opens
// when clicking the clock: media and notifications on the left, the
// calendar on the right.
PopupCard {
    id: popup
    popupName: "calendar"
    align: "center"
    cardWidth: 620
    cardColor: Theme.glassBg

    RowLayout {
        width: parent.width
        spacing: 12

        // ---- Left: media player and notifications ----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            MediaPlayer { Layout.fillWidth: true }

            // Fills the height the calendar sets; the list scrolls inside.
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 400

                ListView {
                    id: notifList
                    anchors.fill: parent
                    visible: Notifications.history.length > 0
                    spacing: 10
                    clip: true
                    model: Notifications.history
                    delegate: NotificationRow {
                        width: notifList.width
                        appName: modelData.appName
                        summary: modelData.summary
                        body: modelData.body || ""
                        appIcon: modelData.appIcon || ""
                        image: modelData.image || ""
                        time: modelData.time
                        onDismissRequested: {
                            var arr = Notifications.history.slice()
                            arr.splice(index, 1)
                            Notifications.history = arr
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    visible: Notifications.history.length === 0
                    spacing: 10
                    SymbolicIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "preferences-system-notifications-symbolic"
                        size: 48
                        tint: Theme.fgDim
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No Notifications"
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    text: "Do Not Disturb"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                }
                ToggleSwitch {
                    checked: Notifications.dnd
                    onToggled: v => Notifications.dnd = v
                }
                Item { Layout.fillWidth: true }
                ChipButton {
                    text: "Clear"
                    enabled: Notifications.history.length > 0
                    onClicked: Notifications.clear()
                }
            }
        }

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            color: Theme.border
        }

        // ---- Right: calendar ----
        ColumnLayout {
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: {
                    var now = Clock.now
                    var wd = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
                    var d = ["January", "February", "March", "April", "May", "June",
                             "July", "August", "September", "October", "November", "December"]
                    return wd[now.getDay()] + ", " + d[now.getMonth()] + " " + now.getDate()
                }
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.Bold
                color: Theme.fg
                horizontalAlignment: Text.AlignHCenter
            }

            RowLayout {
                Layout.fillWidth: true
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
                    font.pixelSize: 15
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

            Calendar {
                id: cal
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 244
            }
        }
    }
}
