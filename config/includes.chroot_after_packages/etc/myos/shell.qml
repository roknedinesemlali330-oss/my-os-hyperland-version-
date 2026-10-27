// MyOS shell: floating shelf, app launcher with search, quick settings panel.
// QML describes WHAT you want to see; Quickshell draws it on top of sway.

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

ShellRoot {
    id: root

    // ----- state -----
    property bool launcherOpen: false
    property bool panelOpen: false
    property string query: ""

    // ----- colors (change these to restyle everything) -----
    readonly property color cShelf: "#F4F6FB"
    readonly property color cAccent: "#4C7BDE"
    readonly property color cText: "#1F2433"
    readonly property color cChip: "#E3E9F6"
    readonly property color cField: "#EEF1F8"

    // ----- apps pinned on the shelf -----
    // id: part of the window's app_id (used to show the "running" dot)
    property var pinned: [
        { id: "foot",     n: "Terminal",    icons: ["utilities-terminal", "terminal"],             cmd: ["foot"] },
        { id: "thunar",   n: "Files",       icons: ["system-file-manager", "thunar"],              cmd: ["thunar"] },
        { id: "firefox",  n: "Browser",     icons: ["firefox-esr", "firefox", "web-browser"],      cmd: ["firefox-esr"] },
        { id: "mousepad", n: "Text Editor", icons: ["accessories-text-editor", "mousepad"],        cmd: ["mousepad"] }
    ]

    // Which compositor are we running on?
    readonly property bool isHypr: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ? true : false

    function switchKeyboard() {
        Quickshell.execDetached(isHypr
            ? ["hyprctl", "switchxkblayout", "all", "next"]
            : ["swaymsg", "input", "type:keyboard", "xkb_switch_layout", "next"])
    }
    function exitSession() {
        Quickshell.execDetached(isHypr ? ["hyprctl", "dispatch", "exit"] : ["swaymsg", "exit"])
    }

    // First icon name that exists in the theme
    function ico(names) {
        for (var i = 0; i < names.length; i++) {
            var p = Quickshell.iconPath(names[i], true)
            if (p !== "") return p
        }
        return Quickshell.iconPath("application-x-executable")
    }

    // Is there an open window for this app?
    function isRunning(id) {
        var t = ToplevelManager.toplevels.values
        for (var i = 0; i < t.length; i++) {
            if ((t[i].appId || "").toLowerCase().indexOf(id) >= 0) return true
        }
        return false
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // All installed apps, filtered by the search text
    ScriptModel {
        id: appModel
        values: DesktopEntries.applications.values
            .filter(function (e) {
                return !e.noDisplay && e.name.toLowerCase().indexOf(root.query.toLowerCase()) >= 0
            })
            .sort(function (a, b) { return a.name.localeCompare(b.name) })
    }

    // Reusable pill button with icon and label
    component QBtn: Rectangle {
        id: b
        property string label
        property string iconName
        property color tint: "#EEF1F8"
        signal clicked()
        height: 44
        radius: 22
        color: ma.containsMouse ? Qt.darker(tint, 1.06) : tint
        Row {
            anchors.centerIn: parent
            spacing: 8
            IconImage {
                implicitSize: 18
                source: Quickshell.iconPath(b.iconName, "application-x-executable")
            }
            Text { text: b.label; color: "#1F2433"; font.pixelSize: 13 }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            onClicked: b.clicked()
        }
    }

    // =====================  SHELF  =====================
    PanelWindow {
        anchors { bottom: true; left: true; right: true }
        margins { bottom: 12; left: 14; right: 14 }
        implicitHeight: 52
        exclusiveZone: 64
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: root.cShelf

            // Launcher: an empty ring
            Rectangle {
                id: ring
                width: 22; height: 22; radius: 11
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                color: "transparent"
                border.width: 3
                border.color: root.cAccent
                scale: ringMa.containsMouse ? 1.12 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }
                MouseArea {
                    id: ringMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        root.panelOpen = false
                        root.launcherOpen = !root.launcherOpen
                    }
                }
            }

            // Pinned apps, centered
            Row {
                anchors.centerIn: parent
                spacing: 12
                Repeater {
                    model: root.pinned
                    delegate: Item {
                        id: cell
                        required property var modelData
                        width: 36; height: 36
                        scale: appMa.containsMouse ? 1.12 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 32
                            source: root.ico(cell.modelData.icons)
                        }
                        // dot under running apps
                        Rectangle {
                            visible: root.isRunning(cell.modelData.id)
                            width: 14; height: 3; radius: 1.5
                            color: root.cAccent
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: -5
                        }
                        MouseArea {
                            id: appMa
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Quickshell.execDetached(cell.modelData.cmd)
                        }
                    }
                }
            }

            // System tray: opens quick settings
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: trayRow.width + 28
                height: 34
                radius: 17
                color: trayMa.containsMouse ? Qt.darker(root.cChip, 1.05) : root.cChip
                Row {
                    id: trayRow
                    anchors.centerIn: parent
                    spacing: 10
                    IconImage {
                        implicitSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                        source: Quickshell.iconPath("network-wireless-symbolic", "network-wireless")
                    }
                    IconImage {
                        implicitSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                        source: Quickshell.iconPath("audio-volume-high-symbolic", "audio-volume-high")
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatTime(clock.date, "hh:mm")
                        color: root.cText
                        font.pixelSize: 13
                    }
                }
                MouseArea {
                    id: trayMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        root.launcherOpen = false
                        root.panelOpen = !root.panelOpen
                    }
                }
            }
        }
    }

    // =====================  LAUNCHER  =====================
    PanelWindow {
        id: launcher
        visible: root.launcherOpen
        focusable: true
        anchors { bottom: true; left: true }
        margins { bottom: 76; left: 14 }
        implicitWidth: 400
        implicitHeight: 460
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        onVisibleChanged: {
            if (visible) {
                openAnim.restart()
                search.text = ""
                root.query = ""
                search.forceActiveFocus()
            }
        }

        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 170 }
            NumberAnimation { target: card; property: "scale"; from: 0.93; to: 1; duration: 170; easing.type: Easing.OutCubic }
        }

        Rectangle {
            id: card
            anchors.fill: parent
            radius: 24
            color: "#FFFFFF"
            transformOrigin: Item.BottomLeft

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // Search field
                Rectangle {
                    width: parent.width
                    height: 42
                    radius: 21
                    color: root.cField

                    TextInput {
                        id: search
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        verticalAlignment: TextInput.AlignVCenter
                        font.pixelSize: 14
                        color: root.cText
                        clip: true
                        onTextChanged: root.query = text
                        Keys.onEscapePressed: root.launcherOpen = false
                        Keys.onReturnPressed: {
                            if (appModel.values.length > 0) {
                                appModel.values[0].execute()
                                root.launcherOpen = false
                            }
                        }
                        Text {
                            visible: search.text.length === 0
                            text: "Search apps"
                            color: "#8A91A8"
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // App grid
                GridView {
                    id: grid
                    width: parent.width
                    height: parent.height - 54
                    cellWidth: width / 4
                    cellHeight: 92
                    clip: true
                    model: appModel

                    delegate: Item {
                        id: gcell
                        required property var modelData
                        width: grid.cellWidth
                        height: grid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 14
                            color: gma.containsMouse ? root.cField : "transparent"
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            IconImage {
                                anchors.horizontalCenter: parent.horizontalCenter
                                implicitSize: 44
                                source: Quickshell.iconPath(gcell.modelData.icon, "application-x-executable")
                            }
                            Text {
                                width: grid.cellWidth - 10
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: gcell.modelData.name
                                font.pixelSize: 12
                                color: root.cText
                            }
                        }
                        MouseArea {
                            id: gma
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                gcell.modelData.execute()
                                root.launcherOpen = false
                            }
                        }
                    }
                }
            }
        }
    }

    // =====================  QUICK SETTINGS  =====================
    PanelWindow {
        visible: root.panelOpen
        anchors { bottom: true; right: true }
        margins { bottom: 76; right: 14 }
        implicitWidth: 300
        implicitHeight: 292
        onVisibleChanged: if (visible) panelAnim.restart()
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        ParallelAnimation {
            id: panelAnim
            NumberAnimation { target: pcard; property: "opacity"; from: 0; to: 1; duration: 170 }
            NumberAnimation { target: pcard; property: "scale"; from: 0.93; to: 1; duration: 170; easing.type: Easing.OutCubic }
        }

        Rectangle {
            id: pcard
            anchors.fill: parent
            radius: 24
            color: "#FFFFFF"
            transformOrigin: Item.BottomRight

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Text {
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                    color: root.cText
                    font.pixelSize: 15
                    font.bold: true
                }

                QBtn {
                    width: parent.width
                    label: "Network settings"
                    iconName: "network-wireless"
                    onClicked: {
                        Quickshell.execDetached(["foot", "-e", "nmtui"])
                        root.panelOpen = false
                    }
                }
                QBtn {
                    width: parent.width
                    label: "Switch keyboard language"
                    iconName: "input-keyboard"
                    onClicked: root.switchKeyboard()
                }
                QBtn {
                    width: parent.width
                    label: "Task manager"
                    iconName: "utilities-system-monitor"
                    onClicked: {
                        Quickshell.execDetached(["lxtask"])
                        root.panelOpen = false
                    }
                }

                Row {
                    width: parent.width
                    spacing: 8
                    QBtn {
                        width: (parent.width - 16) / 3
                        label: "Exit"
                        iconName: "system-log-out"
                        onClicked: root.exitSession()
                    }
                    QBtn {
                        width: (parent.width - 16) / 3
                        label: "Restart"
                        iconName: "system-reboot"
                        onClicked: Quickshell.execDetached(["systemctl", "reboot"])
                    }
                    QBtn {
                        width: (parent.width - 16) / 3
                        tint: "#F7D9D9"
                        label: "Off"
                        iconName: "system-shutdown"
                        onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                    }
                }
            }
        }
    }
}
