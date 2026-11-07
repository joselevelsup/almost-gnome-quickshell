import QtQuick
import QtQuick.Layouts
import ".."

// A single notification: used both in the history (calendar) and in the
// pop-up banners (NotificationToasts).
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

    implicitHeight: layout.implicitHeight + 28
    implicitWidth: 310

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius - 6
        color: root.elevated ? Theme.toastBg
                             : Theme.withAlpha("#ffffff", 0.06)
        border.width: root.elevated ? 1 : 0
        border.color: Theme.border
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        SymbolicIcon {
            name: root.appIcon.length > 0 ? root.appIcon : "dialog-information-symbolic"
            size: 24
            Layout.alignment: Qt.AlignTop
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: root.appName
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    Layout.fillWidth: true
                }
                Text {
                    visible: root.time !== null
                    text: root.time ? Qt.formatTime(root.time, "hh:mm") : ""
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }
            }
            Text {
                text: root.summary
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Text {
                visible: root.body.length > 0
                text: root.body
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: 14
                lineHeight: 1.15
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        BarButton {
            spacing: 0
            implicitWidth: 26
            implicitHeight: 26
            Layout.alignment: Qt.AlignTop
            SymbolicIcon { name: "window-close-symbolic"; size: 13; tint: Theme.fgDim }
            onClicked: root.dismissRequested()
        }
    }
}
