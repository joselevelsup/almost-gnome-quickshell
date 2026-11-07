//@ pragma IconTheme Adwaita
import Quickshell
import QtQuick
import "components"

Scope {
    id: root

    SettingsWindow {}

    // No UI; referencing it starts the idle timers (singletons are lazy).
    readonly property Singleton power: Power

    Variants {
        model: Quickshell.screens

        Background {
            property var modelData
            screen: modelData
        }
    }

    Variants {
        // Settings → Top Bar; every monitor if the chosen one is unplugged.
        model: {
            var picked = Quickshell.screens.filter(s => s.name === Settings.options.barScreen)
            return picked.length ? picked : Quickshell.screens
        }

        Bar {
            property var modelData
            screen: modelData
        }
    }
}
