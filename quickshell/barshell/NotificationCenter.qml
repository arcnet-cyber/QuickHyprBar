import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

PopupWindow {
    id: notifCenter
    visible: false
    implicitWidth: 400
    implicitHeight: 500
    color: "transparent"
    
    property color colBg: "#1a1b26"
    property color colFg: "#a9b1d6"
    property color colMuted: "#444b6a"
    property color colCyan: "#7aa2f7"
    property color colRed: "#f7768e"
    property color colYellow: "#e0af68"
    property color colGreen: "#9ece6a"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 14
    
    property var anchorWindow: null
    property real barWidth: 50
    property real popupY: 40
    property real popupX: barWidth + 8
    
    property var notificationService: null
    
    anchor.window: anchorWindow
    anchor.rect.x: popupX
    anchor.rect.y: popupY
    
    function toggle() {
        visible = !visible
        if (visible && notificationService) {
            notificationService.markAllRead()
        }
    }
    
    Rectangle {
        anchors.fill: parent
        color: colBg
        radius: 12
        border.width: 1
        border.color: colCyan
        clip: true
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                
                Text {
                    text: "Notifications"
                    color: colFg
                    font { family: fontFamily; pixelSize: fontSize + 2; bold: true }
                    Layout.fillWidth: true
                }
                
                Text {
                    text: "Clear All"
                    color: colMuted
                    font { family: fontFamily; pixelSize: fontSize - 2 }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (notificationService) {
                                notificationService.dismissAll()
                            }
                        }
                    }
                }
                
                Text {
                    text: "✕"
                    color: colMuted
                    font { family: fontFamily; pixelSize: fontSize }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notifCenter.visible = false
                    }
                }
            }
            
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: colMuted
                opacity: 0.3
            }
            
            ListView {
                id: notifListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: notificationService ? notificationService.notifications : null
                
                delegate: Rectangle {
                    id: cardItem
                    width: notifListView.width
                    height: Math.max(50, summaryText.height + bodyText.height + 40)
                    radius: 4
                    color: cardMouseArea.containsMouse ? Qt.rgba(0.3, 0.3, 0.4, 0.2) : Qt.rgba(0.3, 0.3, 0.4, 0.1)
                    
                    // Main click target for the notification body
                    MouseArea {
                        id: cardMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        onClicked: {
                            var entry = notificationService.notifications.get(index)
                            if (entry && entry.notificationRef) {
                                // Tells notify-send --wait that the user accepted/clicked it
                                entry.notificationRef.activate("") 
                                notificationService.dismissById(entry.id)
                            }
                        }
                    }
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 2
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            Rectangle {
                                width: 4
                                height: 30
                                radius: 2
                                color: {
                                    if (model.urgency === 2) return colRed
                                    if (model.urgency === 1) return colCyan
                                    return colMuted
                                }
                                Layout.alignment: Qt.AlignVCenter
                            }
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                
                                Text {
                                    id: summaryText
                                    text: model.summary || "Notification"
                                    color: colFg
                                    font { family: fontFamily; pixelSize: fontSize - 2; bold: true }
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                
                                Text {
                                    id: bodyText
                                    text: model.body || ""
                                    color: colMuted
                                    font { family: fontFamily; pixelSize: fontSize - 4 }
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    visible: text !== ""
                                }
                            }
                            
                            ColumnLayout {
                                spacing: 4
                                
                                Text {
                                    text: model.timestamp ? Qt.formatDateTime(model.timestamp, "h:mm AP") : ""
                                    color: colMuted
                                    font { family: fontFamily; pixelSize: fontSize - 6 }
                                }
                                
                                Text {
                                    text: "✕"
                                    color: colMuted
                                    font { family: fontFamily; pixelSize: fontSize - 4 }
                                    // Z-order ensures the individual close button functions over the card click
                                    z: 10 
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (notificationService) {
                                                notificationService.dismissById(model.id)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        Text {
                            text: model.appName || "Unknown"
                            color: colMuted
                            font { family: fontFamily; pixelSize: fontSize - 6 }
                            opacity: 0.7
                        }
                    }
                }
                
                Item {
                    anchors.fill: parent
                    visible: parent.count === 0
                    
                    Text {
                        anchors.centerIn: parent
                        text: "No notifications"
                        color: colMuted
                        font { family: fontFamily; pixelSize: fontSize }
                    }
                }
            }
        }
    }
}
