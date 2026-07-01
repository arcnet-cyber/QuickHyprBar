import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PopupWindow {
	id: powerMenu
	visible: false
	implicitWidth: 160
	implicitHeight: 220
	color: "transparent"

	property color colBg: "#1a1b26"
	property color colFg: "#a9b1d6"
	property color colMuted: "#444b6a"
	property color colYellow: "#e0af68"
	property color colBlue: "#7aa2f7"
	property string fontFamily: "JetBrainsMono Nerd Font"
	property int fontSize: 14

	property var anchorWindow: null
	property real barWidth: 50
	property real popupY: 40

	anchor.window: anchorWindow
	anchor.rect.x: barWidth + 8
	anchor.rect.y: popupY

	function toggleMenu() {
		visible = !visible
	}

	function closeMenu() {
		visible = false
	}

	// --- Actions ---
	Process { id: lockProc; command: ["hyprlock"] }
	Process { id: logoutProc; command: ["hyprshutdown"] }
	Process { id: rebootProc; command: ["reboot"] }
	Process { id: shutdownProc; command: ["shutdown", "now"] }
	Process { id: sleepProc; command: ["systemctl", "suspend"] }

	Rectangle {
		anchors.fill: parent
		color: powerMenu.colBg
		border.color: powerMenu.colBlue
		border.width: 1
		radius:12

		ColumnLayout {
			anchors.fill: parent
			anchors.margins: 8
			spacing: 4

			Repeater {
				model: [
					{ label: "Lock", action: function() { lockProc.running = true } },
					{ label: "Sleep", action: function() { sleepProc.running = true } },
					{ label: "Logout", action: function() { logoutProc.running = true } },
					{ label: "Reboot", action: function() { rebootProc.running = true } },
					{ label: "Shutdown", action: function() { shutdownProc.running = true } }
				]

				Rectangle {
					Layout.fillWidth: true
					height: 36
					radius: 4
					color: itemMouse.containsMouse ? powerMenu.colMuted : "transparent"

					Text {
						anchors.left: parent.left
						anchors.verticalCenter: parent.verticalCenter
						anchors.leftMargin: 10
						text: modelData.label
						color: modelData.label === "Shutdown" ? powerMenu.colYellow : powerMenu.colFg
						font { family: powerMenu.fontFamily; pixelSize: powerMenu.fontSize; bold: true }
					}

					MouseArea {
						id: itemMouse
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: {
							modelData.action()
							powerMenu.closeMenu()
						}
					}
				}
			}
		}
	}
}