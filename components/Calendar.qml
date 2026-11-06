import QtQuick
import ".."

Item {
    id: cal

    property date shownDate
    property int shownYear: shownDate.getFullYear()
    property int shownMonth: shownDate.getMonth()
    property var days: []
    property string monthLabel: ""

    readonly property var months: ["January", "February", "March", "April", "May", "June",
                                   "July", "August", "September", "October", "November", "December"]
    readonly property var weekdays: ["S", "M", "T", "W", "T", "F", "S"]

    function build() {
        var first = new Date(cal.shownYear, cal.shownMonth, 1)
        var offset = first.getDay()
        var total = new Date(cal.shownYear, cal.shownMonth + 1, 0).getDate()
        var arr = []
        for (var i = 0; i < offset; i++) arr.push(null)
        for (var d = 1; d <= total; d++) arr.push(d)
        while (arr.length % 7 !== 0) arr.push(null)
        cal.days = arr
        cal.monthLabel = cal.months[cal.shownMonth] + " " + cal.shownYear
    }

    onShownDateChanged: build()
    Component.onCompleted: cal.shownDate = Clock.now

    function isToday(d) {
        if (d == null) return false
        var now = Clock.now
        return d === now.getDate() && cal.shownMonth === now.getMonth() && cal.shownYear === now.getFullYear()
    }

    function prevMonth() {
        cal.shownMonth--
        if (cal.shownMonth < 0) { cal.shownMonth = 11; cal.shownYear-- }
        cal.shownDate = new Date(cal.shownYear, cal.shownMonth, 1)
        cal.build()
    }

    function nextMonth() {
        cal.shownMonth++
        if (cal.shownMonth > 11) { cal.shownMonth = 0; cal.shownYear++ }
        cal.shownDate = new Date(cal.shownYear, cal.shownMonth, 1)
        cal.build()
    }

    Grid {
        id: grid
        anchors.fill: parent
        columns: 7
        rows: 7
        columnSpacing: 4
        rowSpacing: 4

        Repeater {
            model: 7
            delegate: Item {
                required property int index
                width: grid.width / 7 - 4
                height: 24
                Text {
                    anchors.centerIn: parent
                    text: cal.weekdays[index]
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: Theme.fgDim
                }
            }
        }

        Repeater {
            model: cal.days
            delegate: Item {
                required property var modelData
                width: grid.width / 7 - 4
                height: 24
                Rectangle {
                    anchors.fill: parent
                    radius: 5
                    color: cal.isToday(modelData) ? Theme.accent : "transparent"
                }
                Text {
                    anchors.centerIn: parent
                    text: modelData == null ? "" : modelData
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: cal.isToday(modelData) ? "#ffffff" : Theme.fg
                }
            }
        }
    }
}
