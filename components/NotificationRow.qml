import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import ".."

// A single notification, GNOME 46 style: a header (app icon, app name,
// time, close) above the content (avatar/thumbnail or app icon, title,
// body). Used both in the history (calendar) and in the pop-up banners
// (NotificationToasts).
Item {
    id: root
    property string appName: ""
    property string summary: ""
    property string body: ""
    property string appIcon: ""
    property string image: ""
    property var time: null
    // true when used as a toast: it floats alone and needs its own card; in
    // the calendar history there's already a popup behind it, so the
    // subtle row tint is enough.
    property bool elevated: false
    signal dismissRequested

    // Bare file paths need file:// for Image; Quickshell also wraps
    // image-path hints as image://icon//path, which the icon provider can't load.
    function toUrl(s) {
        s = s.replace(/^image:\/\/icon\/(?=\/)/, "")
        return s.charAt(0) === "/" ? "file://" + s : s
    }
    // appIcon is either a theme icon name or a path/URL.
    readonly property string appIconSource: root.appIcon.length === 0 ? ""
        : root.appIcon.indexOf("/") !== -1 ? root.toUrl(root.appIcon)
        : Quickshell.iconPath(root.appIcon, true)

    implicitHeight: layout.implicitHeight + 24
    implicitWidth: 310

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: root.elevated ? Theme.glassBg
                             : Theme.withAlpha("#ffffff", 0.06)
        border.width: root.elevated ? 1 : 0
        border.color: Theme.border
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 12
        anchors.leftMargin: 14
        spacing: 6

        // ---- Header ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Item {
                implicitWidth: 16
                implicitHeight: 16
                IconImage {
                    visible: root.appIconSource.length > 0
                    anchors.fill: parent
                    implicitSize: 16
                    source: root.appIconSource
                }
                SymbolicIcon {
                    visible: root.appIconSource.length === 0
                    name: "dialog-information-symbolic"
                    tint: Theme.fgDim
                }
            }
            Text {
                text: root.appName
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.maximumWidth: implicitWidth
                Layout.fillWidth: true
            }
            Text {
                text: root.time ? Qt.formatTime(root.time, "hh:mm") : "Just now"
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }
            Item { Layout.fillWidth: true }
            BarButton {
                spacing: 0
                implicitWidth: 24
                implicitHeight: 24
                color: containsMouse ? Theme.cardHoverBg : Theme.cardBg
                SymbolicIcon { name: "window-close-symbolic"; size: 12 }
                onClicked: root.dismissRequested()
            }
        }

        // ---- Content ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Avatar/thumbnail when the notification has one, else the app icon.
            ClippingRectangle {
                visible: root.image.length > 0
                Layout.alignment: Qt.AlignTop
                implicitWidth: 40
                implicitHeight: 40
                radius: 8
                color: "transparent"
                Image {
                    anchors.fill: parent
                    source: root.toUrl(root.image)
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(80, 80)
                    asynchronous: true
                }
            }
            IconImage {
                visible: root.image.length === 0 && root.appIconSource.length > 0
                Layout.alignment: Qt.AlignTop
                implicitSize: 32
                source: root.appIconSource
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: root.summary
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                Text {
                    visible: root.body.length > 0
                    text: root.body
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    lineHeight: 1.15
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }
    }
}
