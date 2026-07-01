import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "services"

ShellRoot {
	// --- Floating clock pill centered at top of screen ---
	PanelWindow {
		id: topBar
		anchors.top: true
		anchors.left: true
		anchors.right: true
		exclusionMode: ExclusionMode.Ignore
		implicitHeight: 34
		color: "transparent"

		Rectangle {
			id: clockPill
			width: topClock.implicitWidth + 24
			height: 34
			anchors.horizontalCenter: parent.horizontalCenter
			anchors.top: parent.top
			color: root.colBg
			border.color: root.colBlue
			border.width: 1
			radius: 17

			Text {
				id: topClock
				anchors.centerIn: parent
				color: root.colBlue
				font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
				text: Qt.formatDateTime(new Date(), "dd/MM  h:mm AP")
				Timer {
					interval: 1000
					running: true
					repeat: true
					onTriggered: topClock.text = Qt.formatDateTime(new Date(), "dd/MM  h:mm AP")
				}
			}
		}
	}

	// --- Sidebar ---
	PanelWindow {
		id: root
		property color colBg: "#1a1b26"
		property color colFg: "#a9b1d6"
		property color colMuted: "#444b6a"
		property color colCyan: "#7aa2f7"
		property color colBlue: "#7aa2f7"
		property color colYellow: "#e0af68"
		property color colRed: "#f7768e"
		property string fontFamily: "JetBrainsMono Nerd Font"
		property int fontSize: 14

		anchors.top: true
		anchors.left: true
		anchors.bottom: true
		implicitWidth: 50
		color: root.colBg

		Notifications {
			id: notifService
			onNewNotification: (notification) => {
				notifPopup.showNotification(notification)
			}
		}

		NotificationCenter {
			id: notifCenter
			anchorWindow: root
			barWidth: root.implicitWidth
			popupY: notifIcon.y + (notifIcon.height / 2) - (implicitHeight / 2)
			notificationService: notifService
			colBg: root.colBg
			colFg: root.colFg
			colMuted: root.colMuted
			colCyan: root.colCyan
			fontFamily: root.fontFamily
			fontSize: root.fontSize
		}

		AppLauncher {
			id: launcher
			colBg: root.colBg
			colFg: root.colFg
			colMuted: root.colMuted
			fontFamily: root.fontFamily
			fontSize: root.fontSize
			anchorWindow: root
			barWidth: root.implicitWidth
		}

		PowerMenu {
			id: powerMenu
			colBg: root.colBg
			colFg: root.colFg
			colMuted: root.colMuted
			colYellow: root.colYellow
			fontFamily: root.fontFamily
			fontSize: root.fontSize
			anchorWindow: root
			barWidth: root.implicitWidth
		}

		NetworkMenu {
			id: netMenu
			colBg: root.colBg
			colFg: root.colFg
			colMuted: root.colMuted
			colCyan: root.colCyan
			colYellow: root.colYellow
			fontFamily: root.fontFamily
			fontSize: root.fontSize
			anchorWindow: root
			barWidth: root.implicitWidth
		}

		BluetoothMenu {
			id: btMenu
			colBg: root.colBg
			colFg: root.colFg
			colMuted: root.colMuted
			colCyan: root.colCyan
			colYellow: root.colYellow
			fontFamily: root.fontFamily
			fontSize: root.fontSize
			anchorWindow: root
			barWidth: root.implicitWidth
		}

		SoundMenu {
			id: soundMenu
			colBg: root.colBg
			colFg: root.colFg
			colMuted: root.colMuted
			colCyan: root.colCyan
			colYellow: root.colYellow
			fontFamily: root.fontFamily
			fontSize: root.fontSize
			anchorWindow: root
			barWidth: root.implicitWidth
		}

		BrightnessMenu {
			id: brightMenu
			colBg: root.colBg
			colFg: root.colFg
			colMuted: root.colMuted
			colYellow: root.colYellow
			fontFamily: root.fontFamily
			fontSize: root.fontSize
			anchorWindow: root
			barWidth: root.implicitWidth
		}

		Rectangle {
			anchors.right: parent.right
			anchors.top: parent.top
			anchors.bottom: parent.bottom
			width: 1
			color: root.colBlue
		}

		Process {
			id: netStatusProc
			command: ["nmcli", "-t", "-f", "CONNECTIVITY", "general", "status"]
			property bool connected: false
			stdout: SplitParser {
				splitMarker: "\n"
				onRead: (line) => {
					netStatusProc.connected = (line.trim() === "full")
				}
			}
			onStarted: connected = false
		}

		Timer {
			interval: 5000
			running: true
			repeat: true
			triggeredOnStart: true
			onTriggered: netStatusProc.running = true
		}

		ColumnLayout {
			anchors.fill: parent
			anchors.margins: 4
			spacing: 7

			Repeater {
				model: 5
				Text {
					Layout.alignment: Qt.AlignHCenter
					property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
					property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)
					text: index + 1
					color: isActive ? root.colCyan : (ws ? root.colBlue : root.colMuted)
					font { family: root.fontFamily; pixelSize: root.fontSize + 1; bold: true }
				}
			}

			Item { Layout.fillHeight: true }

			Text {
				id: launcherIcon
				Layout.alignment: Qt.AlignHCenter
				text: "󱪴"
				property bool hovered: false
				color: launcher.visible ? root.colCyan : (hovered ? root.colBlue : root.colMuted)
				font { family: root.fontFamily; pixelSize: root.fontSize + 2; bold: true }
				MouseArea {
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onEntered: launcherIcon.hovered = true
					onExited: launcherIcon.hovered = false
					onClicked: {
						launcher.popupY = launcherIcon.y + (launcherIcon.height / 2) - (launcher.implicitHeight / 2)
						launcher.toggleLauncher()
					}
				}
			}

			Item { Layout.fillHeight: true }

			Text {
				id: soundIcon
				Layout.alignment: Qt.AlignHCenter
				text: soundMenu.outMuted ? "󰝟" : "\uf028"
				property bool hovered: false
				color: soundMenu.visible ? root.colCyan : (hovered ? root.colBlue : root.colMuted)
				font { family: root.fontFamily; pixelSize: root.fontSize + 2; bold: true }
				MouseArea {
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onEntered: soundIcon.hovered = true
					onExited: soundIcon.hovered = false
					onClicked: {
						soundMenu.popupY = soundIcon.y + (soundIcon.height / 2) - (soundMenu.implicitHeight / 2)
						soundMenu.toggleMenu()
					}
				}
			}

			Text {
				id: brightIcon
				Layout.alignment: Qt.AlignHCenter
				text: "󱠂"
				property bool hovered: false
				color: brightMenu.visible ? root.colCyan : (hovered ? root.colBlue : root.colMuted)
				font { family: root.fontFamily; pixelSize: root.fontSize + 2; bold: true }
				MouseArea {
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onEntered: brightIcon.hovered = true
					onExited: brightIcon.hovered = false
					onClicked: {
						brightMenu.popupY = brightIcon.y + (brightIcon.height / 2) - (brightMenu.implicitHeight / 2)
						brightMenu.toggleMenu()
					}
				}
			}

			Text {
				id: notifIcon
				Layout.alignment: Qt.AlignHCenter
				text: "\uf0f3"
				property bool hovered: false
				color: notifCenter.visible ? root.colCyan :
					   (notifService.unreadCount > 0 ? root.colYellow :
						(hovered ? root.colBlue : root.colMuted))
				font { family: root.fontFamily; pixelSize: root.fontSize + 2; bold: true }

				Rectangle {
					anchors.top: parent.top
					anchors.right: parent.right
					width: 16
					height: 16
					radius: 8
					color: root.colRed
					visible: notifService.unreadCount > 0
					Text {
						anchors.centerIn: parent
						text: notifService.unreadCount > 9 ? "9+" : notifService.unreadCount
						color: root.colBg
						font { family: root.fontFamily; pixelSize: 9; bold: true }
					}
				}

				MouseArea {
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onEntered: notifIcon.hovered = true
					onExited: notifIcon.hovered = false
					onClicked: {
						notifCenter.popupY = notifIcon.y + (notifIcon.height / 2) - (notifCenter.implicitHeight / 2)
						notifCenter.toggle()
					}
				}
			}

			Text {
				id: btIcon
				Layout.alignment: Qt.AlignHCenter
				text: "\uf293"
				property bool hovered: false
				color: btMenu.visible ? root.colCyan : (btMenu.powered ? root.colBlue : root.colMuted)
				font { family: root.fontFamily; pixelSize: root.fontSize + 2; bold: true }
				MouseArea {
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onEntered: btIcon.hovered = true
					onExited: btIcon.hovered = false
					onClicked: {
						btMenu.popupY = btIcon.y + (btIcon.height / 2) - (btMenu.implicitHeight / 2)
						btMenu.toggleMenu()
					}
				}
			}

			Text {
				id: netIcon
				Layout.alignment: Qt.AlignHCenter
				text: netStatusProc.connected ? "\uf1eb" : "\uf071"
				property bool hovered: false
				color: netMenu.visible ? root.colCyan : (netStatusProc.connected ? root.colBlue : root.colYellow)
				font { family: root.fontFamily; pixelSize: root.fontSize + 2; bold: true }
				MouseArea {
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onEntered: netIcon.hovered = true
					onExited: netIcon.hovered = false
					onClicked: {
						netMenu.popupY = netIcon.y + (netIcon.height / 2) - (netMenu.implicitHeight / 2)
						netMenu.toggleMenu()
					}
				}
			}

			Text {
				id: powerIcon
				Layout.alignment: Qt.AlignHCenter
				text: "\u23fb"
				property bool hovered: false
				color: powerMenu.visible ? root.colCyan : (hovered ? root.colBlue : root.colMuted)
				font { family: root.fontFamily; pixelSize: root.fontSize + 2; bold: true }
				MouseArea {
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onEntered: powerIcon.hovered = true
					onExited: powerIcon.hovered = false
					onClicked: {
						powerMenu.popupY = powerIcon.y
						powerMenu.toggleMenu()
					}
				}
			}
		}
	}
}