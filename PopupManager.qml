pragma Singleton
import QtQuick
import Quickshell.Io

// Controla qué popup de la barra está abierto: "calendar", "quicksettings" o "".
// Solo puede haber uno abierto a la vez, como en GNOME Shell.
QtObject {
    id: mgr
    property string current: ""
    // Marca de tiempo del último cambio de popup: las esquinas calientes
    // la usan para no reabrir lo que el usuario acaba de cerrar.
    property double lastChange: 0
    // true → el overview se abre en modo grilla de aplicaciones (esquina
    // inferior izquierda) en vez del mosaico de workspaces.
    property bool appsMode: false

    function open(name) {
        // Con la grilla de apps abierta, el botón del overview pasa al
        // mosaico en vez de cerrar.
        if (mgr.current === name) {
            if (name === "overview" && mgr.appsMode) mgr.appsMode = false
            else mgr.close()
        } else { mgr.appsMode = false; mgr.current = name }
    }
    function openApps() {
        mgr.appsMode = true
        mgr.current = "overview"
    }
    function close() { mgr.current = ""; mgr.appsMode = false }
    onCurrentChanged: mgr.lastChange = Date.now()

    // Para atajos de Hyprland, p. ej. Super → `qs ipc call overview toggle`.
    property IpcHandler screenshotIpc: IpcHandler {
        target: "screenshot"
        function toggle(): void { mgr.open("screenshot") }
    }

    property IpcHandler overviewIpc: IpcHandler {
        target: "overview"
        function toggle(): void { mgr.open("overview") }
        function open(): void { mgr.appsMode = false; mgr.current = "overview" }
        // Grilla de aplicaciones, p. ej. Super+G → `qs ipc call overview apps`.
        function apps(): void { mgr.openApps() }
        function close(): void { if (mgr.current === "overview") mgr.close() }
    }
}
