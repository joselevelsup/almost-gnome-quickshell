pragma Singleton
import QtQuick
import Quickshell.Services.Notifications

// Notification server + history, GNOME style (the same panel shown when
// opening the calendar). Popup banners are handled separately in
// components/NotificationToasts.qml using server.trackedNotifications.
QtObject {
    id: notifications

    property bool dnd: false
    property var history: []
    readonly property int unreadCount: notifications.history.length

    function clear() { notifications.history = [] }

    property NotificationServer server: NotificationServer {
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        keepOnReload: true

        onNotification: function (n) {
            var entry = {
                id: n.id,
                appName: n.appName || "Notification",
                appIcon: n.appIcon,
                summary: n.summary,
                body: n.body,
                urgency: n.urgency,
                image: n.image,
                time: new Date()
            }
            notifications.history = [entry].concat(notifications.history).slice(0, 50)

            // "tracked" keeps the notification alive so it can be shown as a
            // banner; the server removes it from trackedNotifications on its own
            // when it closes (dismiss/expire), without us touching "tracked".
            if (!notifications.dnd) n.tracked = true
        }
    }
}
