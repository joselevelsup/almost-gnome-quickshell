pragma Singleton
import Quickshell
import QtQuick

// Lanza entradas .desktop fuera del cgroup de Quickshell. `entry.execute()`
// (la API nativa de Quickshell) hace fork desde el propio proceso del shell:
// Quickshell.execDetached() solo lo separa de la relación padre-hijo, no lo
// saca del cgroup de systemd.user.services.quickshell. Resultado: un reinicio
// o crash del shell (o systemd-oomd si ese cgroup acumula mucha memoria) se
// lleva por delante cualquier app abierta desde el Dock o el Overview.
//
// `uwsm app` (ya presente: Hyprland corre con withUWSM) resuelve el .desktop
// y lo lanza como su propio scope de systemd en app-graphical.slice,
// completamente aparte. Solo trata el argumento como id de entrada .desktop
// si termina en ".desktop" (ver uwsm/main.py:MainArg) — los ids que maneja
// Quickshell (DesktopEntries, DockPins) no traen esa extensión.
QtObject {
    function launch(entry) {
        if (!entry) return
        Quickshell.execDetached(["uwsm", "app", "--", entry.id + ".desktop"])
    }
}
