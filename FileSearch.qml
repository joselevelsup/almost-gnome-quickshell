pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// File search for the launchers' "/" mode: streams `find` matches over
// $HOME while the walk is still running.
QtObject {
    id: fileSearch

    property string term: ""
    property var results: []

    function search(newTerm) { fileSearch.term = newTerm; fileSearch.debounce.restart() }

    property Timer debounce: Timer {
        interval: 250
        onTriggered: {
            // Stop before reconfiguring: guarantees the new command restarts.
            fileSearch.find.running = false
            // ARGV, never sh -c: the term is user input. maxdepth 4 and
            // pruning hidden entries keep the walk fast.
            fileSearch.find.command = ["find", Quickshell.env("HOME"), "-maxdepth", "4",
                                       "-name", ".*", "-prune", "-o", "-iname",
                                       "*" + fileSearch.term + "*",
                                       "-printf", "%y\t%p\n"]
            fileSearch.results = []
            fileSearch.find.running = true
        }
    }

    property Process find: Process {
        stdout: SplitParser {
            onRead: line => {
                if (fileSearch.results.length >= 30) return
                var i = line.indexOf("\t")
                if (i < 0) return
                var path = line.slice(i + 1)
                // Paths with a quote can't be reopened safely in umbriel's sh.
                if (path.indexOf("'") !== -1) return
                fileSearch.results = fileSearch.results.concat([{ isDir: line.slice(0, i) === "d", path: path }])
                if (fileSearch.results.length >= 30) fileSearch.find.running = false
            }
        }
    }
}
