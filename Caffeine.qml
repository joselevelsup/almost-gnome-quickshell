pragma Singleton
import QtQuick

// "Caffeine": while enabled, inhibits session idle (screen stays on, no
// lock or suspend). Only the state lives here; the actual IdleInhibitor is
// in Bar.qml, because the Wayland protocol (zwp_idle_inhibitor_v1) ties the
// inhibitor to a visible surface and a singleton has no window. Toggled
// from Quick Settings.
QtObject {
    id: root
    property bool enabled: false
}
