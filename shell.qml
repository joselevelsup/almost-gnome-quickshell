//@ pragma IconTheme Adwaita
import Quickshell
import QtQuick
import "components"

Scope {
    id: root

    SettingsWindow {}

    Variants {
        model: Quickshell.screens

        Bar {
            property var modelData
            screen: modelData
        }
    }
}
