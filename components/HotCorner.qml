import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// Esquina caliente: superficie mínima en una esquina de la pantalla que
// dispara una acción cuando el puntero permanece dentro de ella durante
// `delay` ms (pasar de largo no hace nada, como en GNOME). Se instancia
// desde Bar.qml, una por esquina, y solo actúa cuando no hay popup abierto
// para no reabrir el que el usuario acaba de cerrar.
PanelWindow {
    id: hc

    // "top" o "bottom"; siempre la esquina izquierda de la pantalla.
    property string edge: "top"
    // "overview" abre el mosaico de workspaces; "apps" la grilla de apps.
    property string action: "overview"

    readonly property int delay: 180

    WlrLayershell.namespace: "quickshell:hotcorner:" + hc.edge
    WlrLayershell.layer: WlrLayer.Overlay
    anchors {
        left: true
        top: hc.edge === "top"
        bottom: hc.edge === "bottom"
    }
    // La barra reserva arriba (exclusiveZone), así que Hyprland baja esta
    // superficie a y=barHeight; el margen negativo la devuelve a la esquina
    // real de la pantalla, que es donde vive el hot corner.
    margins { top: hc.edge === "top" ? -Theme.barHeight : 0 }
    exclusiveZone: 0
    aboveWindows: true
    focusable: false
    color: "transparent"

    implicitWidth: 6
    implicitHeight: 6

    // Solo dispara una vez por entrada al puntero: queda en false hasta
    // que el puntero salga de la esquina.
    property bool armed: true

    Timer {
        id: arm
        interval: hc.delay
        onTriggered: {
            if (!hc.armed) return
            hc.armed = false
            // Al cerrar un popup el puntero suele seguir en la esquina;
            // se ignora un momento para no reabrirlo en caliente.
            if (Date.now() - PopupManager.lastChange < 500) return
            if (hc.action === "apps") {
                if (PopupManager.current === "overview" && PopupManager.appsMode) return
                PopupManager.openApps()
            } else {
                // Ya abierto no se vuelve a disparar (no alterna): pasar por
                // la esquina con el overview puesto no lo cierra.
                if (PopupManager.current === "overview") return
                PopupManager.open("overview")
            }
        }
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                if (hc.armed) arm.restart()
            } else {
                arm.stop()
                hc.armed = true
            }
        }
    }
}
