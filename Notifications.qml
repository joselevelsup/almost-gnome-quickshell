pragma Singleton
import QtQuick
import Quickshell
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

            // The lock screen is a separate instance and can't see this
            // server, so forward the notification there over IPC; the call
            // is a silent no-op whenever no lock screen is running.
            if (!notifications.dnd) Quickshell.execDetached([
                "qs", "-p", Quickshell.shellPath("lock.qml"), "ipc", "call",
                "locknotify", "show", "--", entry.appName, entry.summary,
                entry.body || "", entry.appIcon || ""
            ])

            // "tracked" keeps the notification alive so it can be shown as a
            // banner; the server removes it from trackedNotifications on its own
            // when it closes (dismiss/expire), without us touching "tracked".
            if (!notifications.dnd) n.tracked = true
        }
    }
}
