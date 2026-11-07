import QtQuick
import ".."

Item {
    id: cal

    property date shownDate
    readonly property int shownYear: shownDate.getFullYear()
    readonly property int shownMonth: shownDate.getMonth()
    property var days: []
    property string monthLabel: ""

    readonly property var months: ["January", "February", "March", "April", "May", "June",
                                   "July", "August", "September", "October", "November", "December"]
    readonly property var weekdays: ["S", "M", "T", "W", "T", "F", "S"]

    // Reads shownDate itself: shownYear/shownMonth may not have updated yet
    // when onShownDateChanged runs.
    function build() {
        var y = cal.shownDate.getFullYear(), m = cal.shownDate.getMonth()
        var offset = new Date(y, m, 1).getDay()
        var total = new Date(y, m + 1, 0).getDate()
        var arr = []
        for (var i = 0; i < offset; i++) arr.push(null)
        for (var d = 1; d <= total; d++) arr.push(d)
        while (arr.length % 7 !== 0) arr.push(null)
        cal.days = arr
        cal.monthLabel = cal.months[m] + " " + y
    }

    onShownDateChanged: build()
    Component.onCompleted: cal.shownDate = Clock.now

    function isToday(d) {
        if (d == null) return false
        var now = Clock.now
        return d === now.getDate() && cal.shownMonth === now.getMonth() && cal.shownYear === now.getFullYear()
    }

    // Date rolls month -1 / 12 over into the neighboring year.
    function prevMonth() { cal.shownDate = new Date(cal.shownDate.getFullYear(), cal.shownDate.getMonth() - 1, 1) }
    function nextMonth() { cal.shownDate = new Date(cal.shownDate.getFullYear(), cal.shownDate.getMonth() + 1, 1) }

    Grid {
        id: grid
        anchors.fill: parent
        columns: 7
        rows: 7
        columnSpacing: 4
        rowSpacing: 4
        // Weekday row + 5 or 6 weeks share the height the popup gives us.
        readonly property real cellHeight: (grid.height - grid.rowSpacing * (cal.days.length / 7)) / (1 + cal.days.length / 7)

        Repeater {
            model: 7
            delegate: Item {
                required property int index
                width: grid.width / 7 - 4
                height: grid.cellHeight
                Text {
                    anchors.centerIn: parent
                    text: cal.weekdays[index]
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.fgDim
                }
            }
        }

        Repeater {
            model: cal.days
            delegate: Item {
                required property var modelData
                width: grid.width / 7 - 4
                height: grid.cellHeight
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height, 36)
                    height: width
                    radius: width / 2
                    color: cal.isToday(modelData) ? Theme.accent : "transparent"
                }
                Text {
                    anchors.centerIn: parent
                    text: modelData == null ? "" : modelData
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    color: cal.isToday(modelData) ? "#ffffff" : Theme.fg
                }
            }
        }
    }
}
