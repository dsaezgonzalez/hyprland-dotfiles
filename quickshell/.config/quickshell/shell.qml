//@ pragma UseQApplication

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import Quickshell.DBusMenu

PanelWindow {
    id: window
    
    anchors {
        top: true
        left: true
        right: true
    }
    
    implicitHeight: 48
    color: "transparent"
    
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bar"

    property int activeWsId: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.activeWorkspace.id : 1
    
    property int highestWsId: {
        let max = 0;
        for (let ws of Hyprland.workspaces.values) {
            if (ws.id > max) max = ws.id;
        }
        return max;
    }
    
    readonly property int displayCount: Math.min(9, Math.max(4, activeWsId, highestWsId))

    // Volume properties
    property int sinkVol: 0
    property bool sinkMuted: false
    property int sourceVol: 0
    property bool sourceMuted: false

    // Network properties
    property string netType: "disconnected"
    property string netName: ""
    property int netSignal: 0
    property bool wifiPowered: false

    // Media properties
    property string mediaStatus: "Stopped"
    property string mediaArtist: ""
    property string mediaTitle: ""
    property string mediaPlayer: ""

    // Control Hub properties
    property int cpuUsage: 0
    property int ramUsage: 0
    property bool controlHubOpen: false
    property bool btPowered: false
    property bool btConnected: false
    property string btDevice: ""
    property bool dndActive: false

    // Wi-Fi Settings popup properties
    property bool wifiSettingsOpen: false
    property string wifiListJson: "[]"
    property string connectingSsid: ""
    property string wifiError: ""

    // Bluetooth Settings popup properties
    property bool bluetoothSettingsOpen: false
    property string bluetoothListJson: "[]"
    property string connectingBluetoothDevice: ""
    property string connectingBluetoothMac: ""
    property string bluetoothError: ""

    // Theme properties
    property color themeAccent:     "#00aaff"
    property color themeSecondary:  "#0044aa"
    property color themeBackground: "#07080d"
    property color themeForeground: "#e8e8ee"
    property bool themeSwitcherOpen: false
    property var wallpaperList: []
    property string activeWallpaper: ""

    // Clipboard properties
    property bool clipboardOpen: false
    property var clipboardList: []

    function addClipboardItem(text) {
        if (!text || text.trim() === "") return;
        
        let existingIndex = -1;
        for (let i = 0; i < clipboardList.length; i++) {
            if (clipboardList[i].text === text) {
                existingIndex = i;
                break;
            }
        }
        
        let newList = Array.from(clipboardList);
        
        if (existingIndex !== -1) {
            let item = newList[existingIndex];
            newList.splice(existingIndex, 1);
            newList.unshift(item);
        } else {
            newList.unshift({ text: text, pinned: false });
        }
        
        while (newList.length > 6) {
            let foundUnpinned = false;
            for (let i = newList.length - 1; i >= 0; i--) {
                if (!newList[i].pinned) {
                    newList.splice(i, 1);
                    foundUnpinned = true;
                    break;
                }
            }
            if (!foundUnpinned) {
                newList.pop();
            }
        }
        
        clipboardList = newList;
    }

    function togglePin(index) {
        if (index >= 0 && index < clipboardList.length) {
            let newList = Array.from(clipboardList);
            newList[index] = {
                text: newList[index].text,
                pinned: !newList[index].pinned
            };
            clipboardList = newList;
        }
    }

    // Notification properties
    property string notifyAppName: ""
    property string notifySummary: ""
    property string notifyBody: ""
    property int notifyId: 0
    property bool notifyVisible: false

    Timer {
        id: notifyExpiryTimer
        interval: 5000
        running: false
        repeat: false
        onTriggered: {
            window.notifyVisible = false;
        }
    }

    // Subprocess monitors
    Process {
        id: notifyProcess
        command: ["/usr/bin/python3", "-u", "/home/diego/.config/quickshell/scripts/notification_daemon.py"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    let data = JSON.parse(line);
                    if (data.type === "notify") {
                        window.notifyAppName = data.app_name;
                        window.notifySummary = data.summary;
                        window.notifyBody = data.body;
                        window.notifyId = data.id;
                        window.notifyVisible = !window.dndActive;
                        
                        notifyExpiryTimer.stop();
                        let timeout = data.expire_timeout;
                        if (timeout <= 0) {
                            timeout = 5000;
                        }
                        notifyExpiryTimer.interval = timeout;
                        notifyExpiryTimer.start();
                    } else if (data.type === "close") {
                        if (window.notifyId === data.id) {
                            window.notifyVisible = false;
                            notifyExpiryTimer.stop();
                        }
                    }
                } catch(e) {
                    console.log("Error parsing notification json:", e);
                }
            }
        }
    }

    Process {
        id: volumeProcess
        command: ["/home/diego/.config/quickshell/scripts/volume_monitor.sh"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    let data = JSON.parse(line);
                    window.sinkVol = data.sink_vol;
                    window.sinkMuted = data.sink_muted;
                    window.sourceVol = data.source_vol;
                    window.sourceMuted = data.source_muted;
                } catch(e) {
                    console.log("Error parsing volume json:", e);
                }
            }
        }
    }

    Process {
        id: networkProcess
        command: ["/home/diego/.config/quickshell/scripts/network_monitor.sh"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    let data = JSON.parse(line);
                    window.netType = data.type;
                    window.netName = data.name;
                    window.netSignal = data.signal;
                    window.wifiPowered = data.wifi_powered;
                } catch(e) {
                    console.log("Error parsing network json:", e);
                }
            }
        }
    }

    Process {
        id: mediaProcess
        command: ["/home/diego/.config/quickshell/scripts/media_monitor.py"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    let data = JSON.parse(line);
                    window.mediaStatus = data.status;
                    window.mediaArtist = data.artist;
                    window.mediaTitle = data.title;
                    window.mediaPlayer = data.player;
                } catch(e) {
                    console.log("Error parsing media json:", e);
                }
            }
        }
    }

    Process {
        id: sysProcess
        command: ["/home/diego/.config/quickshell/scripts/sys_monitor.sh"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    let data = JSON.parse(line);
                    window.cpuUsage = data.cpu;
                    window.ramUsage = data.ram;
                } catch(e) {
                    console.log("Error parsing sys json:", e);
                }
            }
        }
    }

    Process {
        id: bluetoothProcess
        command: ["/home/diego/.config/quickshell/scripts/bluetooth_monitor.sh"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    let data = JSON.parse(line);
                    window.btPowered = data.powered;
                    window.btConnected = data.connected;
                    window.btDevice = data.device;
                } catch(e) {
                    console.log("Error parsing bluetooth json:", e);
                }
            }
        }
    }

    Process {
        id: wifiScanProcess
        command: ["/home/diego/.config/quickshell/scripts/wifi_scan.py"]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                window.wifiListJson = line;
            }
        }
    }

    Process {
        id: wifiConnectProcess
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                console.log("nmcli connect stdout:", line);
            }
        }
        stderr: SplitParser {
            onRead: (line) => {
                console.log("nmcli connect stderr:", line);
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                window.wifiError = "Failed to connect to " + window.connectingSsid;
            } else {
                window.wifiError = "";
                wifiScanProcess.running = true;
            }
            window.connectingSsid = "";
        }
    }

    Process {
        id: bluetoothScanProcess
        command: ["/home/diego/.config/quickshell/scripts/bluetooth_scan.py"]
        running: window.bluetoothSettingsOpen
        stdout: SplitParser {
            onRead: (line) => {
                window.bluetoothListJson = line;
            }
        }
    }

    Process {
        id: bluetoothConnectProcess
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                console.log("bluetooth connect stdout:", line);
            }
        }
        stderr: SplitParser {
            onRead: (line) => {
                console.log("bluetooth connect stderr:", line);
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                window.bluetoothError = "Failed to connect to " + window.connectingBluetoothDevice;
            } else {
                window.bluetoothError = "";
                Quickshell.execDetached(["bluetoothctl", "trust", window.connectingBluetoothMac]);
            }
            window.connectingBluetoothDevice = "";
            window.connectingBluetoothMac = "";
        }
    }

    Process {
        id: clipboardWatcher
        command: ["/home/diego/.config/quickshell/scripts/clipboard_monitor.py"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                let decoded = Qt.atob(line);
                window.addClipboardItem(decoded);
            }
        }
    }

    Process {
        id: themeLoader
        command: ["jq", "-c", ".", "/home/diego/.config/quickshell/themes/active.json"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    let t = JSON.parse(line);
                    window.themeAccent = t.accent;
                    window.themeSecondary = t.secondary_accent;
                    window.themeBackground = t.background;
                    window.themeForeground = t.foreground;
                    window.activeWallpaper = t.wallpaper;
                } catch(e) {}
            }
        }
    }

    Process {
        id: wallpaperScanner
        command: ["find", "/home/diego/.local/share/wallpapers", "-type", "f", "-iregex", ".*\\.\\(jpg\\|jpeg\\|png\\|webp\\)"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                if (line.trim() !== "") {
                    let list = Array.from(window.wallpaperList);
                    list.push(line.trim());
                    window.wallpaperList = list;
                }
            }
        }
    }

    IpcHandler {
        target: "theme"
        function toggle() {
            window.themeSwitcherOpen = !window.themeSwitcherOpen;
        }
        function apply_colours(wallpaper: string, accent: string, secondary: string, background: string, foreground: string) {
            window.activeWallpaper = wallpaper;
            window.themeAccent = accent;
            window.themeSecondary = secondary;
            window.themeBackground = background;
            window.themeForeground = foreground;
        }
    }

    Timer {
        id: wifiScanTimer
        interval: 8000
        running: window.wifiSettingsOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: wifiScanProcess.running = true
    }

    // Bluetooth Scan Timer is removed as we now use a persistent daemon bound to popup state

    Item {
        anchors {
            fill: parent
            margins: 10
        }

        // Left side: Workspaces
        Rectangle {
            id: workspacesPill
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            
            color: Qt.alpha(window.themeBackground, 0.69) 
            border.width: 1
            border.color: window.themeSecondary
            height: 30
            radius: 15
            clip: true
            
            implicitWidth: workspacesRow.width + 20
            
            Behavior on implicitWidth {
                NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
            }

            Rectangle {
                id: activeIndicator
                z: 2
                height: 20
                width: 44
                color: window.themeAccent
                radius: 10
                anchors.verticalCenter: parent.verticalCenter
                
                x: 10 + (Math.min(window.activeWsId, 9) - 1) * 24
                
                Behavior on x { 
                    NumberAnimation { duration: 350; easing.type: Easing.OutQuint } 
                }
            }

            Row {
                id: workspacesRow
                anchors.left: parent.left
                anchors.leftMargin: 10 
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4 

                Repeater {
                    id: workspacesRepeater
                    model: window.displayCount
                    
                    delegate: Rectangle {
                        height: 20
                        radius: 10
                        color: (window.activeWsId === index + 1) ? window.themeAccent : Qt.alpha(window.themeSecondary, 0.5)
                        width: (window.activeWsId === index + 1) ? 44 : 20
                        
                        Behavior on width {
                            NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
                        }
                        
                        Behavior on color {
                            ColorAnimation { duration: 300 }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${index + 1} })`);
                        }
                    }
                }
            }
            
            MouseArea {
                anchors.fill: parent
                z: 1
                acceptedButtons: Qt.NoButton
                cursorShape: Qt.PointingHandCursor
                onWheel: (wheel) => {
                    if (wheel.angleDelta.y > 0) {
                        if (window.activeWsId > 1) Hyprland.dispatch(`hl.dsp.focus({ workspace = ${window.activeWsId - 1} })`);
                    } else {
                        if (window.activeWsId < 9) Hyprland.dispatch(`hl.dsp.focus({ workspace = ${window.activeWsId + 1} })`);
                    }
                }
            }
        }
        
        // Center side: Clock Pill
        Rectangle {
            id: clockPill
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
            }
            height: 30
            radius: 15
            color: window.notifyVisible ? "#b01a0a0d" : Qt.alpha(window.themeBackground, 0.69)
            border.width: 1
            border.color: window.notifyVisible ? "#ff605c" : window.themeAccent
            implicitWidth: window.notifyVisible ? Math.min(500, notifyRow.implicitWidth + 24) : (clockRow.implicitWidth + 24)
            
            Behavior on color { ColorAnimation { duration: 300 } }
            Behavior on border.color { ColorAnimation { duration: 300 } }
            Behavior on implicitWidth {
                NumberAnimation { duration: 350; easing.type: Easing.OutQuint }
            }
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    window.clipboardOpen = !window.clipboardOpen;
                }
            }
            
            Row {
                id: clockRow
                anchors.centerIn: parent
                spacing: 8
                opacity: window.notifyVisible ? 0 : 1
                visible: opacity > 0
                
                Behavior on opacity {
                    NumberAnimation { duration: 250 }
                }
                
                Text {
                    text: ""
                    color: "#ffffff"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.bold: true
                }
                
                Text {
                    id: clockText
                    color: "#ffffff"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.bold: true
                    
                    property string currentTime: ""
                    text: currentTime
                    
                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        triggeredOnStart: true
                        onTriggered: {
                            clockText.currentTime = Qt.formatDateTime(new Date(), "hh:mm  dd MMM yyyy")
                        }
                    }
                }
            }

            Row {
                id: notifyRow
                anchors.centerIn: parent
                spacing: 8
                opacity: window.notifyVisible ? 1 : 0
                visible: opacity > 0
                
                Behavior on opacity {
                    NumberAnimation { duration: 250 }
                }
                
                Text {
                    text: ""
                    color: "#ff605c"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.bold: true
                }
                
                Text {
                    text: window.notifyAppName ? window.notifyAppName : "System"
                    color: "#ff605c"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.bold: true
                }
                
                Text {
                    text: "|"
                    color: "#44ffffff"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                }
                
                Text {
                    text: window.notifySummary + (window.notifyBody ? ": " + window.notifyBody : "")
                    color: "#ffffff"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                    width: Math.min(350, implicitWidth)
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: window.notifyVisible
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    window.notifyVisible = false;
                    notifyExpiryTimer.stop();
                }
            }
        }

        // Right side: Status Indicators & Power Menu
        RowLayout {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            spacing: 8

            // System Tray Container
            Rectangle {
                id: trayPill
                height: 30
                radius: 15
                color: Qt.alpha(window.themeBackground, 0.69)
                border.width: 1
                border.color: window.themeSecondary
                visible: true
                opacity: trayRepeater.count > 0 ? 1 : 0
                implicitWidth: trayRepeater.count > 0 ? trayRow.implicitWidth + 16 : 0
                
                Behavior on opacity { NumberAnimation { duration: 300 } }
                Behavior on implicitWidth {
                    NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
                }
                
                Row {
                    id: trayRow
                    anchors.centerIn: parent
                    spacing: 8
                    
                    Repeater {
                        id: trayRepeater
                        model: SystemTray.items
                        
                        delegate: Item {
                            id: trayDelegate
                            width: 20
                            height: 20
                            
                            IconImage {
                                anchors.fill: parent
                                source: modelData.icon ? modelData.icon : ""
                                
                                Component.onCompleted: {
                                    console.log("Tray item properties for", modelData.id, ":");
                                    for (let key in modelData) {
                                        console.log("  ", key, "=", modelData[key]);
                                    }
                                }
                            }
                            
                            QsMenuAnchor {
                                id: trayMenu
                                menu: modelData.menu
                                anchor {
                                    window: window
                                    rect.x: trayDelegate.mapToItem(window.contentItem, 0, 0).x
                                    rect.y: trayDelegate.mapToItem(window.contentItem, 0, 0).y
                                    rect.width: trayDelegate.width
                                    rect.height: trayDelegate.height
                                    edges: Qt.BottomEdge
                                    gravity: Qt.BottomEdge | Qt.LeftEdge
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        if (modelData.hasMenu) {
                                            trayMenu.open();
                                        }
                                    } else {
                                        modelData.activate();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Media Pill
            Rectangle {
                id: mediaPill
                height: 30
                radius: 15
                color: Qt.alpha(window.themeBackground, 0.69)
                border.width: 1
                border.color: window.themeSecondary
                visible: window.mediaStatus === "Playing" || window.mediaStatus === "Paused"
                implicitWidth: visible ? Math.min(250, mediaRow.implicitWidth + 24) : 0
                clip: true
                
                Behavior on implicitWidth {
                    NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
                }
                
                Row {
                    id: mediaRow
                    anchors.centerIn: parent
                    spacing: 6
                    
                    Text {
                        width: 14
                        horizontalAlignment: Text.AlignHCenter
                        text: window.mediaStatus === "Playing" ? "" : ""
                        color: window.themeAccent
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        font.bold: true
                    }
                    
                    Text {
                        text: (window.mediaArtist ? window.mediaArtist + " - " : "") + window.mediaTitle
                        color: "#ffffff"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        font.bold: true
                        elide: Text.ElideRight
                        width: Math.min(200, implicitWidth)
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["playerctl", "play-pause"])
                    onWheel: (wheel) => {
                        if (wheel.angleDelta.y > 0) {
                            Quickshell.execDetached(["playerctl", "previous"])
                        } else {
                            Quickshell.execDetached(["playerctl", "next"])
                        }
                    }
                }
            }

            // Volume & Network Pill
            Rectangle {
                id: volNetPill
                height: 30
                radius: 15
                color: Qt.alpha(window.themeBackground, 0.69)
                border.width: 1
                border.color: window.themeSecondary
                implicitWidth: volNetRow.implicitWidth + 24
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onClicked: {
                        if (mouse.button === Qt.LeftButton) {
                            window.controlHubOpen = !window.controlHubOpen;
                        }
                    }
                }
                
                Row {
                    id: volNetRow
                    anchors.centerIn: parent
                    spacing: 10
                    z: 1
                    
                    // Left half: Volume
                    Item {
                        width: volContentRow.implicitWidth
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Row {
                            id: volContentRow
                            spacing: 6
                            anchors.verticalCenter: parent.verticalCenter
                            
                             Item {
                                 width: 16
                                 height: 16
                                 anchors.verticalCenter: parent.verticalCenter
                                 
                                 Image {
                                     id: volIconImg
                                     anchors.fill: parent
                                     source: {
                                         if (window.sinkMuted) return "icons/volume-mute.svg";
                                         if (window.sinkVol < 30) return "icons/volume-low.svg";
                                         if (window.sinkVol < 70) return "icons/volume-med.svg";
                                         return "icons/volume-high.svg";
                                     }
                                     sourceSize: Qt.size(16, 16)
                                     smooth: true
                                     visible: false
                                 }
                                 
                                 ColorOverlay {
                                     anchors.fill: parent
                                     source: volIconImg
                                     color: window.sinkMuted ? "#88ffffff" : window.themeAccent
                                 }
                             }
                             
                             Text {
                                 width: 32
                                 horizontalAlignment: Text.AlignLeft
                                 text: window.sinkVol + "%"
                                 color: "#ffffff"
                                 font.family: "JetBrainsMono Nerd Font"
                                 font.pixelSize: 13
                                 font.bold: true
                             }
                            
                            Text {
                                text: "|"
                                color: "#44ffffff"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                            }
                            
                            Text {
                                text: window.sourceMuted ? "" : ""
                                color: window.sourceMuted ? "#ff605c" : window.themeAccent
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.bold: true
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            
                            onClicked: {
                                if (mouse.button === Qt.RightButton) {
                                    Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                                }
                            }
                            onWheel: (wheel) => {
                                if (wheel.angleDelta.y > 0) {
                                    Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%+"])
                                } else {
                                    Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"])
                                }
                            }
                        }
                    }
                    
                    // Separator line
                    Rectangle {
                        width: 1
                        height: 16
                        color: "#33ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    // Right half: Network
                    Item {
                        width: netContentRow.implicitWidth
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Row {
                            id: netContentRow
                            spacing: 6
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Text {
                                text: {
                                    if (window.netType === "wifi") return "";
                                    if (window.netType === "ethernet") return "";
                                    return "⚠";
                                }
                                color: (window.netType === "wifi" || window.netType === "ethernet") ? window.themeAccent : "#ff605c"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.bold: true
                            }
                            
                            Text {
                                text: {
                                    if (window.netType === "wifi" || window.netType === "ethernet") return window.netName;
                                    return "Disconnected";
                                }
                                color: (window.netType === "wifi" || window.netType === "ethernet") ? "#ffffff" : "#88ffffff"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.bold: true
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (mouse.button === Qt.RightButton) {
                                    Quickshell.execDetached(["kitty", "-e", "nmtui"])
                                }
                            }
                        }
                    }

                    // Separator line for status icons
                    Rectangle {
                        width: 1
                        height: 16
                        color: "#33ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                        visible: window.btPowered || window.dndActive
                    }

                    // Status icons (Bluetooth / DND)
                    Row {
                        spacing: 8
                        anchors.verticalCenter: parent.verticalCenter
                        visible: window.btPowered || window.dndActive
                        
                        Text {
                            text: ""
                            color: window.btConnected ? "#66cc99" : window.themeAccent
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.bold: true
                            visible: window.btPowered
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Rectangle {
                            width: 1
                            height: 12
                            color: "#33ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            visible: window.btPowered && window.dndActive
                        }
                        
                        Text {
                            text: ""
                            color: "#ff605c"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.bold: true
                            visible: window.dndActive
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }



            // Power Button
            Rectangle {
                id: powerMenu
                
                property bool isOpen: false
                
                height: 30
                width: 30
                radius: 15
                color: isOpen ? window.themeAccent : Qt.alpha(window.themeBackground, 0.69)
                border.width: 1
                border.color: isOpen ? "#ffffff" : window.themeSecondary
                
                Behavior on color {
                    ColorAnimation { duration: 250 }
                }

                Item {
                    id: iconContainer
                    anchors.centerIn: parent
                    width: 18
                    height: 18

                    Image {
                        id: powerIconImage
                        anchors.fill: parent
                        source: "turn-off-svgrepo-com.svg"
                        sourceSize: Qt.size(18, 18)
                        smooth: true
                        visible: false
                    }

                    ColorOverlay {
                        anchors.fill: parent
                        source: powerIconImage
                        color: powerMenu.isOpen ? "black" : window.themeAccent
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: powerMenu.isOpen = !powerMenu.isOpen
                }
            }
        }
    }

    // Popup window for morphing power menu
    PopupWindow {
        id: powerPopup
        visible: powerMenu.isOpen || (powerTransOpen && powerTransOpen.running) || (powerTransClose && powerTransClose.running)
        
        color: "transparent"
        
        anchor {
            item: powerMenu
            edges: Edges.Bottom | Edges.Right
            gravity: Edges.Bottom | Edges.Left
            margins.top: 6
        }
        
        implicitWidth: 260
        implicitHeight: 180
        
        Rectangle {
            id: morphingBox
            focus: true
            Keys.onEscapePressed: {
                powerMenu.isOpen = false;
            }
            
            state: powerMenu.isOpen ? "open" : "closed"
            
            color: Qt.alpha(window.themeBackground, 0.69)
            border.width: 1
            border.color: window.themeSecondary
            clip: true
            
            Grid {
                id: popupGrid
                anchors.fill: parent
                anchors.margins: 16
                columns: 2
                rows: 2
                spacing: 16
                
                opacity: (morphingBox.state === "open" && morphingBox.width > 200) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                
                readonly property var options: [
                    { name: "Power Off", icon: "icons/shutdown.svg", cmd: ["systemctl", "poweroff"] },
                    { name: "Sleep", icon: "icons/sleep.svg", cmd: ["systemctl", "suspend"] },
                    { name: "Reboot", icon: "icons/reboot.svg", cmd: ["systemctl", "reboot"] },
                    { name: "Lock", icon: "icons/logout.svg", cmd: ["hyprlock"] }
                ]

                Repeater {
                    model: popupGrid.options
                    
                    delegate: Rectangle {
                        width: 106
                        height: 66
                        radius: 12
                        color: btnMouseArea.containsMouse ? "#2000aaff" : "#0cffffff"
                        border.width: 1
                        border.color: btnMouseArea.containsMouse ? "#aa00aaff" : "#08ffffff"
                        
                        scale: btnMouseArea.containsMouse ? 1.03 : 1.0
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        
                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            
                            Item {
                                width: 24
                                height: 24
                                anchors.horizontalCenter: parent.horizontalCenter
                                
                                Image {
                                    anchors.fill: parent
                                    source: modelData.icon
                                    sourceSize: Qt.size(24, 24)
                                    smooth: true
                                }
                            }
                            
                            Text {
                                text: modelData.name
                                color: "white"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.bold: true
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                        
                        MouseArea {
                            id: btnMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            
                            onClicked: {
                                powerMenu.isOpen = false;
                                Quickshell.execDetached(modelData.cmd);
                            }
                        }
                    }
                }
            }
            
            states: [
                State {
                    name: "closed"
                    PropertyChanges { target: morphingBox; x: 260 - 30; y: 0; width: 30; height: 30; radius: 15 }
                },
                State {
                    name: "open"
                    PropertyChanges { target: morphingBox; x: 0; y: 0; width: 260; height: 180; radius: 18 }
                }
            ]
            
            transitions: [
                Transition {
                    id: powerTransOpen
                    from: "closed"; to: "open"
                    ParallelAnimation {
                        NumberAnimation { properties: "x,y,width,height,radius"; duration: 400; easing.type: Easing.OutBack; easing.amplitude: 1.05 }
                    }
                },
                Transition {
                    id: powerTransClose
                    from: "open"; to: "closed"
                    ParallelAnimation {
                        NumberAnimation { properties: "x,y,width,height,radius"; duration: 250; easing.type: Easing.OutQuint }
                    }
                }
            ]
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: powerMenu.isOpen
        windows: [powerPopup]
        onCleared: {
            powerMenu.isOpen = false;
        }
    }

    // Popup window for Center Control Hub
    PopupWindow {
        id: controlHubPopup
        visible: window.controlHubOpen || (hubTransOpen && hubTransOpen.running) || (hubTransClose && hubTransClose.running)
        
        color: "transparent"
        
        anchor {
            item: volNetPill
            edges: Edges.Bottom | Edges.Right
            gravity: Edges.Bottom | Edges.Left
            margins.top: 6
        }
        
        implicitWidth: 320
        implicitHeight: 390
        
        Rectangle {
            id: controlHubBox
            radius: 20
            focus: true
            Keys.onEscapePressed: {
                window.controlHubOpen = false;
            }
            state: window.controlHubOpen ? "open" : "closed"
            color: "transparent"
            clip: true
            
            Rectangle {
                id: hubBg
                anchors.fill: parent
                radius: controlHubBox.radius
                color: Qt.alpha(window.themeBackground, 0.69)
                
                border.width: 1
                border.color: controlHubBox.state === "open" ? window.themeSecondary : "transparent"
                
                Behavior on border.color {
                    ColorAnimation { duration: 350 }
                }
            }
            
            Column {
                id: hubContent
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14
                
                opacity: (controlHubBox.state === "open" && controlHubBox.width > 280) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                
                Row {
                    width: parent.width
                    spacing: 8
                    
                    Item {
                        width: 18
                        height: 18
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Image {
                            id: hubTitleIconImg
                            anchors.fill: parent
                            source: "icons/control-hub.svg"
                            sourceSize: Qt.size(18, 18)
                            smooth: true
                            visible: false
                        }
                        
                        ColorOverlay {
                            anchors.fill: parent
                            source: hubTitleIconImg
                            color: "white"
                        }
                    }
                    
                    Text {
                        text: "System Control Hub"
                        color: "white"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#22ffffff"
                }
                
                Column {
                    width: parent.width
                    spacing: 8
                    Row {
                        width: parent.width
                        height: 24
                        spacing: 10
                        
                        Item {
                            width: 24
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Image {
                                id: hubSpkIconImg
                                width: 16
                                height: 16
                                anchors.centerIn: parent
                                source: window.sinkMuted ? "icons/volume-mute.svg" : "icons/volume-high.svg"
                                sourceSize: Qt.size(16, 16)
                                smooth: true
                                visible: false
                            }
                            
                            ColorOverlay {
                                anchors.fill: hubSpkIconImg
                                source: hubSpkIconImg
                                color: "white"
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                            }
                        }
                        
                        Item {
                            id: spkSlider
                            width: 190
                            height: 20
                            anchors.verticalCenter: parent.verticalCenter
                            
                            property real val: window.sinkVol / 100
                            
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 4
                                radius: 2
                                color: "#33ffffff"
                                
                                Rectangle {
                                    anchors.left: parent.left
                                    height: parent.height
                                    width: parent.width * spkSlider.val
                                    radius: 2
                                    color: window.themeAccent
                                }
                            }
                            
                            Rectangle {
                                width: 12
                                height: 12
                                radius: 6
                                color: "#ffffff"
                                anchors.verticalCenter: parent.verticalCenter
                                x: (190 - width) * spkSlider.val
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                
                                function updateValue(mouse) {
                                    let v = Math.max(0, Math.min(1, mouse.x / width));
                                    Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", v.toFixed(2)]);
                                }
                                
                                onPressed: updateValue(mouse)
                                onPositionChanged: updateValue(mouse)
                            }
                        }
                        
                        Text {
                            text: window.sinkVol + "%"
                            color: "#cccccc"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    
                    Row {
                        width: parent.width
                        height: 24
                        spacing: 10
                        
                        Item {
                            width: 24
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Text {
                                text: window.sourceMuted ? "" : ""
                                color: "white"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 15
                                anchors.centerIn: parent
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"])
                            }
                        }
                        
                        Item {
                            id: micSlider
                            width: 190
                            height: 20
                            anchors.verticalCenter: parent.verticalCenter
                            
                            property real val: window.sourceVol / 100
                            
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 4
                                radius: 2
                                color: "#33ffffff"
                                
                                Rectangle {
                                    anchors.left: parent.left
                                    height: parent.height
                                    width: parent.width * micSlider.val
                                    radius: 2
                                    color: window.themeAccent
                                }
                            }
                            
                            Rectangle {
                                width: 12
                                height: 12
                                radius: 6
                                color: "#ffffff"
                                anchors.verticalCenter: parent.verticalCenter
                                x: (190 - width) * micSlider.val
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                
                                function updateValue(mouse) {
                                    let v = Math.max(0, Math.min(1, mouse.x / width));
                                    Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", v.toFixed(2)]);
                                }
                                
                                onPressed: updateValue(mouse)
                                onPositionChanged: updateValue(mouse)
                            }
                        }
                        
                        Text {
                            text: window.sourceVol + "%"
                            color: "#cccccc"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
                
                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#22ffffff"
                }
                
                Row {
                    width: parent.width
                    spacing: 20
                    
                    Column {
                        spacing: 4
                        Text {
                            text: "CPU: " + window.cpuUsage + "%"
                            color: "#cccccc"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.bold: true
                        }
                        Rectangle {
                            width: 132
                            height: 6
                            radius: 3
                            color: "#22ffffff"
                            Rectangle {
                                height: parent.height
                                width: parent.width * (window.cpuUsage / 100)
                                radius: 3
                                color: "#66cc99"
                                Behavior on width { NumberAnimation { duration: 300 } }
                            }
                        }
                    }
                    
                    Column {
                        spacing: 4
                        Text {
                            text: "RAM: " + window.ramUsage + "%"
                            color: "#cccccc"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.bold: true
                        }
                        Rectangle {
                            width: 132
                            height: 6
                            radius: 3
                            color: "#22ffffff"
                            Rectangle {
                                height: parent.height
                                width: parent.width * (window.ramUsage / 100)
                                radius: 3
                                color: "#9b59b6"
                                Behavior on width { NumberAnimation { duration: 300 } }
                            }
                        }
                    }
                }
                
                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#22ffffff"
                }
                
                Grid {
                    columns: 2
                    spacing: 12
                    width: parent.width
                    
                    // Button 1: Wifi
                    Rectangle {
                        width: 136
                        height: 36
                        radius: 8
                        color: netBtnMouse.containsMouse ? "#22ffffff" : "#11ffffff"
                        border.width: 1
                        border.color: netBtnMouse.containsMouse ? "#44ffffff" : "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 8
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            text: "  Wifi settings"
                            color: "white"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.bold: true
                        }
                        
                        MouseArea {
                            id: netBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                window.controlHubOpen = false;
                                window.wifiSettingsOpen = true;
                            }
                        }
                    }
                    
                    // Button 2: Bluetooth
                    Rectangle {
                        width: 136
                        height: 36
                        radius: 8
                        color: window.btConnected ? "#2000aaff" : (btBtnMouse.containsMouse ? "#22ffffff" : "#11ffffff")
                        border.width: 1
                        border.color: window.btConnected ? "#6600aaff" : (btBtnMouse.containsMouse ? "#44ffffff" : "transparent")
                        
                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 8
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            text: {
                                if (window.btConnected) return "  " + (window.btDevice ? window.btDevice : "Connected");
                                if (window.btPowered) return "  Bluetooth On";
                                return "  Bluetooth Off";
                            }
                            color: window.btPowered ? "white" : "#88ffffff"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.bold: true
                        }
                        
                        MouseArea {
                            id: btBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                window.controlHubOpen = false;
                                window.bluetoothSettingsOpen = true;
                            }
                        }
                    }
                    
                    // Button 3: Audio Mixer
                    Rectangle {
                        width: 136
                        height: 36
                        radius: 8
                        color: mixerBtnMouse.containsMouse ? "#22ffffff" : "#11ffffff"
                        border.width: 1
                        border.color: mixerBtnMouse.containsMouse ? "#44ffffff" : "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "  Audio Mixer"
                            color: "white"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.bold: true
                        }
                        
                        MouseArea {
                            id: mixerBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                window.controlHubOpen = false;
                                Quickshell.execDetached(["pavucontrol"]);
                            }
                        }
                    }
                    
                    // Button 4: DND
                    Rectangle {
                        width: 136
                        height: 36
                        radius: 8
                        color: window.dndActive ? "#2000aaff" : (dndBtnMouse.containsMouse ? "#22ffffff" : "#11ffffff")
                        border.width: 1
                        border.color: window.dndActive ? "#6600aaff" : (dndBtnMouse.containsMouse ? "#44ffffff" : "transparent")
                        
                        Text {
                            anchors.centerIn: parent
                            text: window.dndActive ? "  DND: On" : "  DND: Off"
                            color: "white"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.bold: true
                        }
                        
                        MouseArea {
                            id: dndBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                window.dndActive = !window.dndActive;
                            }
                        }
                    }
                }
                
                Rectangle {
                    width: parent.width
                    height: 48
                    radius: 8
                    color: "#11ffffff"
                    visible: window.mediaStatus === "Playing" || window.mediaStatus === "Paused"
                    clip: true
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        
                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2
                            
                            Text {
                                text: window.mediaTitle
                                color: "white"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                font.bold: true
                                elide: Text.ElideRight
                                width: 140
                            }
                            Text {
                                text: window.mediaArtist
                                color: "#88ffffff"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                width: 140
                            }
                        }
                        
                        Row {
                            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                            spacing: 8
                            
                            Item {
                                width: 24
                                height: 24
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    color: prevMouse.containsMouse ? window.themeAccent : "white"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    font.bold: true
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                
                                MouseArea {
                                    id: prevMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["playerctl", "previous"])
                                }
                            }
                            
                            Item {
                                width: 24
                                height: 24
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: window.mediaStatus === "Playing" ? "" : ""
                                    color: playMouse.containsMouse ? window.themeAccent : "white"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    font.bold: true
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                
                                MouseArea {
                                    id: playMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["playerctl", "play-pause"])
                                }
                            }
                            
                            Item {
                                width: 24
                                height: 24
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    color: nextMouse.containsMouse ? window.themeAccent : "white"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    font.bold: true
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                
                                MouseArea {
                                    id: nextMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["playerctl", "next"])
                                }
                            }
                        }
                    }
                }
            }
            
            states: [
                State {
                    name: "closed"
                    PropertyChanges { 
                        target: controlHubBox; 
                        x: 320 - volNetPill.width; 
                        y: 0; 
                        width: volNetPill.width; 
                        height: 30; 
                        radius: 15 
                    }
                },
                State {
                    name: "open"
                    PropertyChanges { 
                        target: controlHubBox; 
                        x: 0; 
                        y: 0; 
                        width: 320; 
                        height: 390; 
                        radius: 20 
                    }
                }
            ]
            
            transitions: [
                Transition {
                    id: hubTransOpen
                    from: "closed"; to: "open"
                    ParallelAnimation {
                        NumberAnimation { 
                            properties: "x,y,width,height,radius"; 
                            duration: 400; 
                            easing.type: Easing.OutBack; 
                            easing.amplitude: 1.05 
                        }
                    }
                },
                Transition {
                    id: hubTransClose
                    from: "open"; to: "closed"
                    ParallelAnimation {
                        NumberAnimation { 
                            properties: "x,y,width,height,radius"; 
                            duration: 250; 
                            easing.type: Easing.OutQuint 
                        }
                    }
                }
            ]
        }
    }

    HyprlandFocusGrab {
        id: hubFocusGrab
        active: window.controlHubOpen
        windows: [controlHubPopup]
        onCleared: {
            window.controlHubOpen = false;
        }
    }

    // Popup window for Wifi Settings (Appealing, Friendly Floating Center Popup)
    PopupWindow {
        id: wifiSettingsPopup
        visible: window.wifiSettingsOpen || (wifiTransOpen && wifiTransOpen.running) || (wifiTransClose && wifiTransClose.running)
        
        color: "transparent"
        
        anchor {
            window: window
            rect.x: (window.width - wifiSettingsPopup.implicitWidth) / 2
            rect.y: (window.screen ? window.screen.height : 1080) / 2 - wifiSettingsPopup.implicitHeight / 2
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | Edges.Right
        }
        
        implicitWidth: 380
        implicitHeight: 460
        
        Rectangle {
            id: wifiSettingsBox
            focus: true
            Keys.onEscapePressed: {
                window.wifiSettingsOpen = false;
            }
            state: window.wifiSettingsOpen ? "open" : "closed"
            anchors.fill: parent
            color: "transparent"
            clip: true
            
            Rectangle {
                id: wifiBg
                anchors.fill: parent
                radius: 20
                color: Qt.alpha(window.themeBackground, 0.69)
                border.width: 1
                border.color: window.themeSecondary
            }
            
            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16
                
                Item {
                    width: parent.width
                    height: 24
                    
                    Text {
                        text: "  Network Connections"
                        color: "white"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        font.bold: true
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Item {
                        width: 24
                        height: 24
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: closeMouse.containsMouse ? "#ff605c" : "#88ffffff"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.wifiSettingsOpen = false
                        }
                    }
                }
                
                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#22ffffff"
                }
                
                // Wi-Fi Power Toggle Row (Premium Switch Control)
                Item {
                    width: parent.width
                    height: 24
                    
                    Text {
                        text: "Wi-Fi Power"
                        color: "white"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.bold: true
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Rectangle {
                        id: wifiSwitchTrack
                        width: 44
                        height: 24
                        radius: 12
                        color: window.wifiPowered ? window.themeAccent : "#22ffffff"
                        border.width: 1
                        border.color: window.wifiPowered ? window.themeAccent : "#44ffffff"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        Rectangle {
                            id: wifiSwitchThumb
                            width: 18
                            height: 18
                            radius: 9
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                            x: window.wifiPowered ? parent.width - width - 3 : 3
                            
                            Behavior on x {
                                NumberAnimation { duration: 200; easing.type: Easing.OutQuint }
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let targetState = !window.wifiPowered;
                                window.wifiPowered = targetState;
                                Quickshell.execDetached(["nmcli", "radio", "wifi", targetState ? "on" : "off"]);
                            }
                        }
                    }
                }
                
                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#11ffffff"
                }
                
                Text {
                    text: window.wifiError
                    color: "#ff605c"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.bold: true
                    visible: window.wifiError !== ""
                    width: parent.width
                    wrapMode: Text.Wrap
                }
                
                ListView {
                    id: wifiListView
                    width: parent.width
                    height: parent.height - 120 - (window.wifiError !== "" ? 24 : 0)
                    spacing: 8
                    clip: true
                    
                    property string selectedSsid: ""
                    
                    model: {
                        try {
                            return JSON.parse(window.wifiListJson);
                        } catch(e) {
                            return [];
                        }
                    }
                    
                    delegate: Rectangle {
                        width: wifiListView.width
                        
                        property bool isSelected: wifiListView.selectedSsid === modelData.ssid
                        
                        height: isSelected ? (modelData.active ? 80 : 96) : 44
                        radius: 12
                        
                        color: modelData.active ? "#2000aaff" : (delegateMouse.containsMouse ? "#22ffffff" : "#11ffffff")
                        border.width: 1
                        border.color: modelData.active ? "#6600aaff" : (delegateMouse.containsMouse ? "#44ffffff" : "transparent")
                        
                        Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        
                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8
                            
                            Row {
                                width: parent.width
                                spacing: 10
                                
                                Text {
                                    text: ""
                                    color: {
                                        if (modelData.active) return "#66cc99";
                                        if (modelData.signal > 75) return "#66cc99";
                                        if (modelData.signal > 50) return "#f39c12";
                                        return "#e74c3c";
                                    }
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Text {
                                    text: modelData.ssid
                                    color: "white"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Text {
                                    text: ""
                                    color: "#88ffffff"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    visible: modelData.security !== "none"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Rectangle {
                                    height: 16
                                    width: 70
                                    radius: 8
                                    color: "#2066cc99"
                                    visible: modelData.active
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Connected"
                                        color: "#66cc99"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 9
                                        font.bold: true
                                    }
                                }
                            }
                            
                            // For secure, non-active networks: Password & Connect & optional Forget button
                            Row {
                                width: parent.width
                                spacing: 8
                                visible: isSelected && !modelData.active
                                
                                Rectangle {
                                    width: modelData.saved ? 150 : 210
                                    height: 28
                                    radius: 6
                                    color: "#22000000"
                                    border.width: 1
                                    border.color: pwdInput.activeFocus ? "#aa00aaff" : "#44ffffff"
                                    clip: true
                                    
                                    TextInput {
                                        id: pwdInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: "white"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        echoMode: TextInput.Password
                                        
                                        Text {
                                            text: modelData.saved ? "Saved (enter to change)..." : "Enter password..."
                                            color: "#66ffffff"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            visible: !pwdInput.text && !pwdInput.activeFocus
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                                
                                Rectangle {
                                    width: 70
                                    height: 28
                                    radius: 6
                                    color: connectBtnMouse.containsMouse ? "#aa00aaff" : window.themeAccent
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Connect"
                                        color: "white"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                    
                                    MouseArea {
                                        id: connectBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            window.connectingSsid = modelData.ssid;
                                            window.wifiError = "";
                                            if (modelData.saved && pwdInput.text === "") {
                                                wifiConnectProcess.command = [
                                                    "nmcli", "connection", "up", "id", modelData.ssid
                                                ];
                                            } else {
                                                wifiConnectProcess.command = [
                                                    "nmcli", "device", "wifi", "connect", 
                                                    modelData.ssid, "password", pwdInput.text
                                                ];
                                            }
                                            wifiConnectProcess.running = true;
                                        }
                                    }
                                }
                                
                                Rectangle {
                                    width: 70
                                    height: 28
                                    radius: 6
                                    color: forgetBtnMouse.containsMouse ? "#44ff605c" : "#20ff605c"
                                    border.width: 1
                                    border.color: "#ff605c"
                                    visible: modelData.saved
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Forget"
                                        color: "#ff605c"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                    
                                    MouseArea {
                                        id: forgetBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            window.connectingSsid = modelData.ssid;
                                            window.wifiError = "";
                                            wifiConnectProcess.command = [
                                                "nmcli", "connection", "delete", "id", modelData.ssid
                                            ];
                                            wifiConnectProcess.running = true;
                                            wifiListView.selectedSsid = "";
                                        }
                                    }
                                }
                            }
                            
                            // For connected network: Disconnect option
                            Row {
                                width: parent.width
                                spacing: 10
                                visible: isSelected && modelData.active
                                
                                Rectangle {
                                    width: 100
                                    height: 28
                                    radius: 6
                                    color: disconnectBtnMouse.containsMouse ? "#44ff605c" : "#20ff605c"
                                    border.width: 1
                                    border.color: "#ff605c"
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Disconnect"
                                        color: "#ff605c"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                    
                                    MouseArea {
                                        id: disconnectBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            window.connectingSsid = modelData.ssid;
                                            window.wifiError = "";
                                            wifiConnectProcess.command = [
                                                "nmcli", "device", "disconnect", "wlan0"
                                            ];
                                            wifiConnectProcess.running = true;
                                        }
                                    }
                                }
                                
                                Process {
                                    id: revealProcess
                                    command: []
                                    stdout: SplitParser {
                                        onRead: (line) => {
                                            if (line.trim() !== "") {
                                                revealText.text = line.trim();
                                            }
                                        }
                                    }
                                }
                                
                                Rectangle {
                                    width: revealText.text === "Reveal Pwd" ? 100 : revealText.implicitWidth + 20
                                    height: 28
                                    radius: 6
                                    color: revealBtnMouse.containsMouse ? Qt.alpha(window.themeAccent, 0.4) : Qt.alpha(window.themeAccent, 0.2)
                                    border.width: 1
                                    border.color: window.themeAccent
                                    
                                    Text {
                                        id: revealText
                                        anchors.centerIn: parent
                                        text: "Reveal Pwd"
                                        color: window.themeAccent
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                    
                                    MouseArea {
                                        id: revealBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (revealText.text === "Reveal Pwd") {
                                                revealProcess.command = ["nmcli", "-s", "-g", "802-11-wireless-security.psk", "connection", "show", modelData.ssid];
                                                revealProcess.running = true;
                                            } else {
                                                revealText.text = "Reveal Pwd";
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        MouseArea {
                            id: delegateMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            z: -1
                            onClicked: {
                                if (modelData.active) {
                                    wifiListView.selectedSsid = (wifiListView.selectedSsid === modelData.ssid ? "" : modelData.ssid);
                                    return;
                                }
                                if (modelData.security === "none" || modelData.security === "") {
                                    window.connectingSsid = modelData.ssid;
                                    window.wifiError = "";
                                    wifiConnectProcess.command = [
                                        "nmcli", "device", "wifi", "connect", modelData.ssid
                                    ];
                                    wifiConnectProcess.running = true;
                                } else {
                                    wifiListView.selectedSsid = (wifiListView.selectedSsid === modelData.ssid ? "" : modelData.ssid);
                                }
                            }
                        }
                    }
                }
            }
            
            // Connecting overlay
            Rectangle {
                anchors.fill: parent
                color: "#dd11111b"
                visible: window.connectingSsid !== ""
                radius: 24
                
                Column {
                    anchors.centerIn: parent
                    spacing: 16
                    
                    Text {
                        id: spinnerIcon
                        text: ""
                        color: window.themeAccent
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 32
                        anchors.horizontalCenter: parent.horizontalCenter
                        
                        NumberAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 1000
                            running: window.connectingSsid !== ""
                            loops: Animation.Infinite
                        }
                    }
                    
                    Text {
                        text: "Connecting to " + window.connectingSsid + "..."
                        color: "white"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
            
            states: [
                State {
                    name: "closed"
                    PropertyChanges { target: wifiSettingsBox; scale: 0.8; opacity: 0 }
                },
                State {
                    name: "open"
                    PropertyChanges { target: wifiSettingsBox; scale: 1.0; opacity: 1 }
                }
            ]
            
            transitions: [
                Transition {
                    id: wifiTransOpen
                    from: "closed"; to: "open"
                    ParallelAnimation {
                        NumberAnimation { properties: "scale"; duration: 350; easing.type: Easing.OutBack; easing.amplitude: 1.02 }
                        NumberAnimation { properties: "opacity"; duration: 250; easing.type: Easing.OutQuad }
                    }
                },
                Transition {
                    id: wifiTransClose
                    from: "open"; to: "closed"
                    ParallelAnimation {
                        NumberAnimation { properties: "scale"; duration: 250; easing.type: Easing.OutQuad }
                        NumberAnimation { properties: "opacity"; duration: 200; easing.type: Easing.OutQuad }
                    }
                }
            ]
        }
    }

    HyprlandFocusGrab {
        id: wifiFocusGrab
        active: window.wifiSettingsOpen
        windows: [wifiSettingsPopup]
        onCleared: {
            window.wifiSettingsOpen = false;
        }
    }

    // Popup window for Bluetooth Settings
    PopupWindow {
        id: bluetoothSettingsPopup
        visible: window.bluetoothSettingsOpen || (btTransOpen && btTransOpen.running) || (btTransClose && btTransClose.running)
        
        color: "transparent"
        
        anchor {
            window: window
            rect.x: (window.width - bluetoothSettingsPopup.implicitWidth) / 2
            rect.y: (window.screen ? window.screen.height : 1080) / 2 - bluetoothSettingsPopup.implicitHeight / 2
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | Edges.Right
        }
        
        implicitWidth: 380
        implicitHeight: 460
        
        Rectangle {
            id: bluetoothSettingsBox
            focus: true
            Keys.onEscapePressed: {
                window.bluetoothSettingsOpen = false;
            }
            state: window.bluetoothSettingsOpen ? "open" : "closed"
            anchors.fill: parent
            color: "transparent"
            clip: true
            
            Rectangle {
                id: btBg
                anchors.fill: parent
                radius: 20
                color: Qt.alpha(window.themeBackground, 0.69)
                border.width: 1
                border.color: window.themeSecondary
            }
            
            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16
                
                Item {
                    width: parent.width
                    height: 24
                    
                    Text {
                        text: "  Bluetooth Devices"
                        color: "white"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        font.bold: true
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Item {
                        width: 24
                        height: 24
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: btCloseMouse.containsMouse ? "#ff605c" : "#88ffffff"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        
                        MouseArea {
                            id: btCloseMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.bluetoothSettingsOpen = false
                        }
                    }
                }
                
                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#22ffffff"
                }
                
                // Bluetooth Power Toggle Row (Premium Switch Control)
                Item {
                    width: parent.width
                    height: 24
                    
                    Text {
                        text: "Bluetooth Power"
                        color: "white"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.bold: true
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Rectangle {
                        id: btSwitchTrack
                        width: 44
                        height: 24
                        radius: 12
                        color: window.btPowered ? window.themeAccent : "#22ffffff"
                        border.width: 1
                        border.color: window.btPowered ? window.themeAccent : "#44ffffff"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        Rectangle {
                            id: btSwitchThumb
                            width: 18
                            height: 18
                            radius: 9
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                            x: window.btPowered ? parent.width - width - 3 : 3
                            
                            Behavior on x {
                                NumberAnimation { duration: 200; easing.type: Easing.OutQuint }
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let targetState = !window.btPowered;
                                window.btPowered = targetState;
                                Quickshell.execDetached(["bluetoothctl", "power", targetState ? "on" : "off"]);
                            }
                        }
                    }
                }
                
                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#11ffffff"
                }
                
                Text {
                    text: window.bluetoothError
                    color: "#ff605c"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.bold: true
                    visible: window.bluetoothError !== ""
                    width: parent.width
                    wrapMode: Text.Wrap
                }
                
                ListView {
                    id: btListView
                    width: parent.width
                    height: parent.height - 120 - (window.bluetoothError !== "" ? 24 : 0)
                    spacing: 8
                    clip: true
                    
                    model: {
                        try {
                            return JSON.parse(window.bluetoothListJson);
                        } catch(e) {
                            return [];
                        }
                    }
                    
                    delegate: Rectangle {
                        width: btListView.width
                        height: 44
                        radius: 12
                        
                        color: modelData.connected ? "#2000aaff" : (btDelegateMouse.containsMouse ? "#22ffffff" : "#11ffffff")
                        border.width: 1
                        border.color: modelData.connected ? "#6600aaff" : (btDelegateMouse.containsMouse ? "#44ffffff" : "transparent")
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12
                            
                            Text {
                                text: ""
                                color: modelData.connected ? "#66cc99" : (modelData.paired ? window.themeAccent : "#88ffffff")
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 16
                                Layout.alignment: Qt.AlignVCenter
                            }
                            
                            Text {
                                text: modelData.name
                                color: "white"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                            
                            Rectangle {
                                height: 16
                                width: modelData.connected ? 70 : 50
                                radius: 8
                                color: modelData.connected ? "#2066cc99" : "#20ffffff"
                                visible: modelData.connected || modelData.paired
                                Layout.alignment: Qt.AlignVCenter
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.connected ? "Connected" : "Paired"
                                    color: modelData.connected ? "#66cc99" : "#cccccc"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 9
                                    font.bold: true
                                }
                            }
                        }
                        
                        MouseArea {
                            id: btDelegateMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.connected) {
                                    Quickshell.execDetached(["bluetoothctl", "disconnect", modelData.mac]);
                                } else {
                                    window.connectingBluetoothDevice = modelData.name;
                                    window.connectingBluetoothMac = modelData.mac;
                                    window.bluetoothError = "";
                                    bluetoothConnectProcess.command = ["bluetoothctl", "connect", modelData.mac];
                                    bluetoothConnectProcess.running = true;
                                }
                            }
                        }
                    }
                }
            }
            
            Rectangle {
                anchors.fill: parent
                color: "#dd11111b"
                visible: window.connectingBluetoothDevice !== ""
                radius: 20
                
                Column {
                    anchors.centerIn: parent
                    spacing: 16
                    
                    Text {
                        text: ""
                        color: window.themeAccent
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 32
                        anchors.horizontalCenter: parent.horizontalCenter
                        
                        NumberAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 1000
                            running: window.connectingBluetoothDevice !== ""
                            loops: Animation.Infinite
                        }
                    }
                    
                    Text {
                        text: "Connecting to " + window.connectingBluetoothDevice + "..."
                        color: "white"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
            
            states: [
                State {
                    name: "closed"
                    PropertyChanges { target: bluetoothSettingsBox; scale: 0.8; opacity: 0 }
                },
                State {
                    name: "open"
                    PropertyChanges { target: bluetoothSettingsBox; scale: 1.0; opacity: 1 }
                }
            ]
            
            transitions: [
                Transition {
                    id: btTransOpen
                    from: "closed"; to: "open"
                    ParallelAnimation {
                        NumberAnimation { properties: "scale"; duration: 350; easing.type: Easing.OutBack; easing.amplitude: 1.02 }
                        NumberAnimation { properties: "opacity"; duration: 250; easing.type: Easing.OutQuad }
                    }
                },
                Transition {
                    id: btTransClose
                    from: "open"; to: "closed"
                    ParallelAnimation {
                        NumberAnimation { properties: "scale"; duration: 250; easing.type: Easing.OutQuad }
                        NumberAnimation { properties: "opacity"; duration: 200; easing.type: Easing.OutQuad }
                    }
                }
            ]
        }
    }

    HyprlandFocusGrab {
        id: bluetoothFocusGrab
        active: window.bluetoothSettingsOpen
        windows: [bluetoothSettingsPopup]
        onCleared: {
            window.bluetoothSettingsOpen = false;
        }
    }

    IpcHandler {
        target: "clipboard"
        
        function toggle() {
            window.clipboardOpen = !window.clipboardOpen;
        }
    }

    // Popup window for Clipboard Manager (3x2 Grid)
    PopupWindow {
        id: clipboardPopup
        visible: window.clipboardOpen || (clipTransOpen && clipTransOpen.running) || (clipTransClose && clipTransClose.running)
        
        color: "transparent"
        
        anchor {
            item: clockPill
            edges: Edges.Bottom
            gravity: Edges.Bottom
            margins.top: 6
        }
        
        implicitWidth: 500
        implicitHeight: 180
        
        Rectangle {
            id: clipboardBox
            state: window.clipboardOpen ? "open" : "closed"
            color: "transparent"
            clip: true
            anchors.fill: parent
            
            focus: true
            Keys.onEscapePressed: {
                window.clipboardOpen = false;
            }
            
            Rectangle {
                id: clipBg
                anchors.fill: parent
                radius: clipboardBox.radius
                color: Qt.alpha(window.themeBackground, 0.69)
                
                border.width: 1
                border.color: window.themeSecondary
            }
            
            Grid {
                id: clipGrid
                anchors.fill: parent
                anchors.margins: 14
                columns: 3
                rows: 2
                spacing: 10
                
                opacity: (clipboardBox.state === "open" && clipboardBox.width > 400) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                
                Repeater {
                    model: 6
                    delegate: Rectangle {
                        width: (clipGrid.width - 20) / 3
                        height: (clipGrid.height - 10) / 2
                        radius: 10
                        
                        property bool hasData: index < window.clipboardList.length
                        property var itemData: hasData ? window.clipboardList[index] : null
                        
                        color: (hasData && itemData && itemData.pinned) ? "#2500aaff" : (cellMouse.containsMouse ? "#20ffffff" : "#10ffffff")
                        border.width: 1
                        border.color: (hasData && itemData && itemData.pinned) ? "#aa00aaff" : (cellMouse.containsMouse ? "#45ffffff" : "#20ffffff")
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        
                        Text {
                            anchors.fill: parent
                            anchors.margins: 8
                            anchors.rightMargin: 20
                            text: (hasData && itemData) ? itemData.text : ""
                            color: "#e5ffffff"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                            maximumLineCount: 3
                        }
                        
                        Text {
                            anchors {
                                top: parent.top
                                right: parent.right
                                topMargin: 6
                                rightMargin: 6
                            }
                            text: ""
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            color: (hasData && itemData && itemData.pinned) ? window.themeAccent : "#44ffffff"
                            visible: hasData && itemData && (itemData.pinned || cellMouse.containsMouse)
                        }
                        
                        Text {
                            anchors.centerIn: parent
                            text: "Empty"
                            color: "#15ffffff"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            visible: !hasData
                        }
                        
                        MouseArea {
                            id: cellMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: hasData ? Qt.PointingHandCursor : Qt.ArrowCursor
                            
                            onClicked: (mouse) => {
                                if (!hasData) return;
                                if (mouse.button === Qt.LeftButton) {
                                    Quickshell.execDetached(["wl-copy", "--", itemData.text]);
                                    window.clipboardOpen = false;
                                } else if (mouse.button === Qt.RightButton) {
                                    window.togglePin(index);
                                }
                            }
                        }
                    }
                }
            }
            
            states: [
                State {
                    name: "closed"
                    PropertyChanges {
                        target: clipboardBox
                        x: (500 - clockPill.width) / 2
                        y: 0
                        width: clockPill.width
                        height: 30
                        radius: 15
                    }
                },
                State {
                    name: "open"
                    PropertyChanges {
                        target: clipboardBox
                        x: 0
                        y: 0
                        width: 500
                        height: 180
                        radius: 20
                    }
                }
            ]
            
            transitions: [
                Transition {
                    id: clipTransOpen
                    from: "closed"; to: "open"
                    ParallelAnimation {
                        NumberAnimation { properties: "x,y,width,height,radius"; duration: 350; easing.type: Easing.OutBack; easing.amplitude: 1.02 }
                    }
                },
                Transition {
                    id: clipTransClose
                    from: "open"; to: "closed"
                    ParallelAnimation {
                        NumberAnimation { properties: "x,y,width,height,radius"; duration: 250; easing.type: Easing.OutQuint }
                    }
                }
            ]
        }
    }

    HyprlandFocusGrab {
        id: clipboardFocusGrab
        active: window.clipboardOpen
        windows: [clipboardPopup]
        onCleared: {
            window.clipboardOpen = false;
        }
    }

    // Popup window for Theme Switcher
    PopupWindow {
        id: themePopup
        visible: window.themeSwitcherOpen || (themeTransOpen && themeTransOpen.running) || (themeTransClose && themeTransClose.running)
        
        color: "transparent"
        
        anchor {
            item: clockPill
            edges: Edges.Bottom
            gravity: Edges.Bottom
            margins.top: 6
        }
        
        implicitWidth: 520
        implicitHeight: 320

        HyprlandFocusGrab {
            active: window.themeSwitcherOpen
            windows: [themePopup]
            onCleared: window.themeSwitcherOpen = false
        }

        Item {
            id: themeContentItem
            anchors.fill: parent
            clip: true
            
            Rectangle {
                id: themeBgRect
                anchors.fill: parent
                color: Qt.alpha(window.themeBackground, 0.95)
                border.width: 1
                border.color: window.themeSecondary
                radius: 12
            }
            
            Keys.onEscapePressed: window.themeSwitcherOpen = false
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                
                Text {
                    text: "🎨 Theme Switcher"
                    color: window.themeForeground
                    font.pixelSize: 16
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }
                
                GridView {
                    id: themeGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: window.wallpaperList
                    cellWidth: 166
                    cellHeight: 166
                    
                    focus: true
                    keyNavigationEnabled: true
                    keyNavigationWraps: true
                    
                    delegate: Item {
                        id: delegateRoot
                        width: 156
                        height: 156
                        
                        Rectangle {
                            id: thumbRect
                            anchors.fill: parent
                            radius: 8
                            color: "transparent"
                            border.width: thumbRect.isActive ? 2 : (delegateRoot.GridView.isCurrentItem ? 2 : 0)
                            border.color: thumbRect.isActive ? window.themeAccent : (delegateRoot.GridView.isCurrentItem ? window.themeForeground : "transparent")
                            
                            property bool isActive: modelData === window.activeWallpaper
                            
                            Image {
                                anchors.fill: parent
                                anchors.margins: (thumbRect.isActive || delegateRoot.GridView.isCurrentItem) ? 2 : 0
                                source: "file:///home/diego/.cache/qs-themes/" + modelData.split('/').pop() + ".thumb.jpg"
                                fillMode: Image.PreserveAspectCrop
                                layer.enabled: true
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle {
                                        width: 156
                                        height: 156
                                        radius: 6
                                    }
                                }
                            }
                            
                            Rectangle {
                                anchors.fill: parent
                                color: mouseArea.containsMouse ? "#22ffffff" : (delegateRoot.GridView.isCurrentItem ? "#11ffffff" : "transparent")
                                radius: 8
                                
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            
                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    themeGrid.currentIndex = index
                                    themeGrid.applySelectedTheme()
                                }
                            }
                        }
                    }
                    
                    Keys.onLeftPressed: (event) => { moveCurrentIndexLeft(); event.accepted = true; }
                    Keys.onRightPressed: (event) => { moveCurrentIndexRight(); event.accepted = true; }
                    Keys.onUpPressed: (event) => { moveCurrentIndexUp(); event.accepted = true; }
                    Keys.onDownPressed: (event) => { moveCurrentIndexDown(); event.accepted = true; }
                    Keys.onReturnPressed: (event) => { applySelectedTheme(); event.accepted = true; }
                    Keys.onSpacePressed: (event) => { applySelectedTheme(); event.accepted = true; }
                    Keys.onEscapePressed: (event) => { window.themeSwitcherOpen = false; event.accepted = true; }
                    
                    function applySelectedTheme() {
                        let wallpaper = window.wallpaperList[currentIndex]
                        if (wallpaper) {
                            Quickshell.execDetached(["/home/diego/.config/quickshell/scripts/theme_apply.sh", wallpaper])
                            window.themeSwitcherOpen = false
                        }
                    }
                }
            }

            transform: Scale {
                id: themeScale
                origin.x: 260
                origin.y: 0
                xScale: 1.0
                yScale: 1.0
            }
            
            opacity: 1.0
        }
        
        ParallelAnimation {
            id: themeTransOpen
            NumberAnimation { target: themeContentItem; property: "opacity"; from: 0; to: 1; duration: 300; easing.type: Easing.OutQuint }
            NumberAnimation { target: themeScale; property: "xScale"; from: 0.1; to: 1.0; duration: 300; easing.type: Easing.OutQuint }
            NumberAnimation { target: themeScale; property: "yScale"; from: 0.1; to: 1.0; duration: 300; easing.type: Easing.OutQuint }
        }
        
        ParallelAnimation {
            id: themeTransClose
            NumberAnimation { target: themeContentItem; property: "opacity"; from: 1; to: 0; duration: 250; easing.type: Easing.InQuint }
            NumberAnimation { target: themeScale; property: "xScale"; from: 1.0; to: 0.1; duration: 250; easing.type: Easing.InQuint }
            NumberAnimation { target: themeScale; property: "yScale"; from: 1.0; to: 0.1; duration: 250; easing.type: Easing.InQuint }
        }
        
        onVisibleChanged: {
            if (visible && window.themeSwitcherOpen) {
                themeTransOpen.restart();
                let activeIdx = window.wallpaperList.indexOf(window.activeWallpaper);
                themeGrid.currentIndex = activeIdx >= 0 ? activeIdx : 0;
                themeGrid.forceActiveFocus();
            } else if (!window.themeSwitcherOpen && visible) {
                themeTransClose.restart();
            }
        }
    }
}
