import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ShellRoot {
    id: root

    Timer {
        id: delayExitTimer
        interval: 50
        repeat: false
        onTriggered: Qt.quit()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: launcherWindow
            required property var modelData
            screen: modelData
            
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrLayershell.Exclusive

            implicitWidth: 320
            implicitHeight: 420
            color: "transparent"

            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }

            WlrLayershell.margins {
                left: (launcherWindow.screen.width - launcherWindow.implicitWidth) / 2
                right: (launcherWindow.screen.width - launcherWindow.implicitWidth) / 2
                top: (launcherWindow.screen.height - launcherWindow.implicitHeight) / 2
                bottom: (launcherWindow.screen.height - launcherWindow.implicitHeight) / 2
            }

            // Styling Parameters
            property color colBg: "#1a1b26"
            property color colFg: "#a9b1d6"
            property color colMuted: "#444b6a"
            property color colBorder: "#7aa2f7" 
            property string fontFamily: "JetBrainsMono Nerd Font"
            property int fontSize: 14

            ScriptModel {
                id: filteredAppsModel
                values: {
                    const allEntries = [...DesktopEntries.applications.values]
                        .filter(d => d && d.name)
                        .sort((a, b) => a.name.localeCompare(b.name))

                    const query = searchField.text.trim().toLowerCase()
                    
                    appList.currentIndex = 0 
                    
                    if (query === "") return allEntries

                    return allEntries.filter(d => {
                        const name = (d.name || "").toLowerCase()
                        const genericName = (d.genericName || "").toLowerCase()
                        return name.includes(query) || genericName.includes(query)
                    })
                }
            }

            Component.onCompleted: {
                searchField.forceActiveFocus()
            }

            // FIXED: Independent Global Shortcut captures Return/Enter cleanly out of the TextField event loop
            Shortcut {
                sequences: ["Return", "Enter"]
                onActivated: {
                    if (filteredAppsModel.count > 0 && appList.currentItem) {
                        const targetApp = appList.currentItem.modelData
                        if (targetApp) {
                            targetApp.execute()
                            delayExitTimer.start()
                        }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                color: launcherWindow.colBg
                radius: 12
                clip: true 
                border.color: launcherWindow.colBorder
                border.width: 2

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14 
                    spacing: 6

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: "Search apps or ESC to close"
                        color: launcherWindow.colFg
                        background: Rectangle { color: launcherWindow.colMuted; radius: 4 }
                        font { family: launcherWindow.fontFamily; pixelSize: launcherWindow.fontSize }
                        
                        onTextChanged: filteredAppsModel.update()
                        Keys.onEscapePressed: Qt.quit()
                        
                        // Handle arrow navigation exclusively here
                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Down) {
                                appList.incrementCurrentIndex();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                appList.decrementCurrentIndex();
                                event.accepted = true;
                            }
                        }
                    }

                    ListView {
                        id: appList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: filteredAppsModel
                        
                        highlightMoveDuration: 150
                        currentIndex: 0

                        delegate: Rectangle {
                            id: rowWrapper
                            width: appList.width
                            height: 36
                            radius: 4
                            
                            required property int index
                            required property var modelData
                            
                            property bool isCurrentKeyboardItem: index === appList.currentIndex
                            
                            color: (appMouse.containsMouse || isCurrentKeyboardItem) ? launcherWindow.colMuted : "transparent"
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                spacing: 8
                                
                                Text {
                                    text: rowWrapper.modelData.name || "Unknown App"
                                    color: launcherWindow.colFg
                                    font { family: launcherWindow.fontFamily; pixelSize: launcherWindow.fontSize }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                            
                            MouseArea {
                                id: appMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                
                                onPositionChanged: appList.currentIndex = rowWrapper.index
                                
                                onClicked: {
                                    rowWrapper.modelData.execute()
                                    delayExitTimer.start()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
