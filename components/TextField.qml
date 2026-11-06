import QtQuick
import ".."

// Single-line text entry, libadwaita style. `committed` fires on Enter or
// focus loss, and only when the text passes the validator.
Rectangle {
    id: field
    property alias text: input.text
    property alias validator: input.validator
    property string placeholder: ""
    signal edited(string text)
    signal committed(string text)

    implicitWidth: 200
    implicitHeight: 34
    radius: Theme.radius - 8
    color: Theme.cardBg
    border.width: input.activeFocus ? 2 : 0
    border.color: input.acceptableInput ? Theme.accent : Theme.danger

    TextInput {
        id: input
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.fg
        selectionColor: Theme.activeBg
        selectedTextColor: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: 13
        clip: true
        selectByMouse: true
        onTextEdited: field.edited(text)
        onEditingFinished: if (acceptableInput) field.committed(text)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length === 0
            text: field.placeholder
            color: Theme.fgDim
            font: input.font
        }
    }
}
