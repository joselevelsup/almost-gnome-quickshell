//@ pragma IconTheme Adwaita
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import "components"

// GNOME-style lock screen, run as its own Quickshell instance:
//   qs -d -p ~/.config/quickshell/lock.qml
// Kept out of the shell so a shell crash or config reload can't touch it.
// Locks on start through ext-session-lock (Sway keeps everything covered
// even if this process dies) and exits once unlocked.
ShellRoot {
    id: root
    // Editing the config must never reload a running lock screen.
    settings.watchFiles: false

    // Shared by every monitor's surface.
    property string buffer: ""
    property bool prompting: false
    property string errorText: ""
    property int failures: 0
    readonly property bool busy: pam.active

    readonly property string user: Quickshell.env("USER") || ""
    property string realName: ""

    function submit() {
        if (root.busy || root.buffer.length === 0) return
        root.errorText = ""
        if (!pam.start()) root.errorText = "Authentication couldn't start"
    }

    PamContext {
        id: pam
        // The password is collected before starting, so answer as soon as PAM asks.
        onPamMessage: {
            if (responseRequired) respond(root.buffer)
            else if (messageIsError) root.errorText = message
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                lock.locked = false
                // Give the unlock request time to reach Sway: exiting while
                // still locked would leave the session locked for good.
                quitTimer.start()
                return
            }
            root.buffer = ""
            root.failures++
            root.errorText = result === PamResult.Failed ? "Sorry, that didn't work. Please try again."
                : result === PamResult.MaxTries ? "Too many attempts. Please wait and try again."
                : "Authentication error"
        }
    }

    WlSessionLock {
        id: lock
        locked: true
        LockSurface { ctx: root }
    }

    Timer { id: quitTimer; interval: 500; onTriggered: Qt.quit() }

    // If another locker already holds the session, this lock never engages:
    // nothing to unlock, so just exit.
    Timer {
        interval: 3000
        running: !lock.secure
        onTriggered: {
            console.warn("Session lock was not granted (another locker running?); exiting")
            Qt.quit()
        }
    }

    // Display name from the passwd GECOS field, like GNOME.
    Process {
        running: root.user.length > 0
        command: ["getent", "passwd", root.user]
        stdout: StdioCollector {
            onStreamFinished: root.realName = (text.split(":")[4] || "").split(",")[0]
        }
    }
}
