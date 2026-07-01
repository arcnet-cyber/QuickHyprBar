import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PopupWindow {
	id: networkMenu
	visible: false
	implicitWidth: 280
	implicitHeight: 320
	color: "transparent"

	property color colBg: "#1a1b26"
	property color colFg: "#a9b1d6"
	property color colMuted: "#444b6a"
	property color colCyan: "#0db9d7"
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

	property var networks: []
	property string connectingSsid: ""
	property var _scanBuffer: []

	function toggleMenu() {
		if (visible) {
			closeMenu()
		} else {
			openMenu()
		}
	}

	function openMenu() {
		visible = true
		refreshScan()
	}

	function closeMenu() {
		visible = false
		connectingSsid = ""
	}

	function refreshScan() {
		scanProc.running = true
	}

	function connectToNetwork(ssid, password) {
		connectProc.running = false
		if (password && password.length > 0) {
			connectProc.command = ["nmcli", "device", "wifi", "connect", ssid, "password", password]
		} else {
			connectProc.command = ["nmcli", "device", "wifi", "connect", ssid]
		}
		connectProc.running = true
	}

	Process {
		id: scanProc
		command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list"]

		stdout: SplitParser {
			splitMarker: "\n"
			onRead: (line) => {
				networkMenu._scanBuffer.push(line)
			}
		}

		onStarted: networkMenu._scanBuffer = []

		onExited: (exitCode) => {
			const buf = networkMenu._scanBuffer
			const parsed = []
			const seen = {}
			for (const line of buf) {
				if (!line) continue
				const parts = line.split(":")
				const inUse = parts[0] === "*"
				const ssid = parts[1]
				const signal = parseInt(parts[2]) || 0
				const security = parts[3] || ""
				if (!ssid || seen[ssid]) continue
				seen[ssid] = true
				parsed.push({ ssid: ssid, signal: signal, secured: security.length > 0, inUse: inUse })
			}
			parsed.sort((a, b) => b.signal - a.signal)
			networkMenu.networks = parsed
		}
	}

	Process {
		id: connectProc
		onExited: (exitCode) => {
			networkMenu.connectingSsid = ""
			networkMenu.refreshScan()
		}
	}

	Timer {
		interval: 10000
		running: networkMenu.visible
		repeat: true
		onTriggered: networkMenu.refreshScan()
	}

	Rectangle {
		anchors.fill: parent
		color: networkMenu.colBg
		border.color: networkMenu.colBlue
		border.width: 1
        radius:12

		ColumnLayout {
			anchors.fill: parent
			anchors.margins: 8
			spacing: 6

			RowLayout {
				Layout.fillWidth: true
				Text {
					text: "Wi-Fi Networks"
					color: networkMenu.colFg
					font { family: networkMenu.fontFamily; pixelSize: networkMenu.fontSize; bold: true }
					Layout.fillWidth: true
				}
				Text {
					id: refreshIcon
					text: "\uf021"
					property bool hovered: false
					color: hovered ? networkMenu.colCyan : networkMenu.colMuted
					font { family: networkMenu.fontFamily; pixelSize: networkMenu.fontSize }
					MouseArea {
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onEntered: refreshIcon.hovered = true
						onExited: refreshIcon.hovered = false
						onClicked: networkMenu.refreshScan()
					}
				}
			}

			ListView {
				id: netList
				Layout.fillWidth: true
				Layout.fillHeight: true
				clip: true
				model: networkMenu.networks
				spacing: 2

				delegate: ColumnLayout {
					width: netList.width
					spacing: 0

					Rectangle {
						Layout.fillWidth: true
						height: 36
						radius: 4
						color: rowMouse.containsMouse ? networkMenu.colMuted : "transparent"

						RowLayout {
							anchors.fill: parent
							anchors.leftMargin: 8
							anchors.rightMargin: 8
							spacing: 6

							Text {
								text: modelData.inUse ? "\uf1eb" : (modelData.secured ? "\uf023" : "\uf09e")
								color: modelData.inUse ? networkMenu.colCyan : networkMenu.colFg
								font { family: networkMenu.fontFamily; pixelSize: networkMenu.fontSize }
							}

							Text {
								text: modelData.ssid
								color: networkMenu.colFg
								font { family: networkMenu.fontFamily; pixelSize: networkMenu.fontSize }
								elide: Text.ElideRight
								Layout.fillWidth: true
							}

							Text {
								text: modelData.signal + "%"
								color: networkMenu.colMuted
								font { family: networkMenu.fontFamily; pixelSize: networkMenu.fontSize - 2 }
							}
						}

						MouseArea {
							id: rowMouse
							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							onClicked: {
								if (modelData.inUse) return
								if (modelData.secured) {
									networkMenu.connectingSsid = (networkMenu.connectingSsid === modelData.ssid) ? "" : modelData.ssid
								} else {
									networkMenu.connectToNetwork(modelData.ssid, "")
								}
							}
						}
					}

					RowLayout {
						Layout.fillWidth: true
						visible: networkMenu.connectingSsid === modelData.ssid
						spacing: 4

						TextField {
							id: pwField
							Layout.fillWidth: true
							placeholderText: "Password"
							echoMode: TextInput.Password
							color: networkMenu.colFg
							background: Rectangle { color: networkMenu.colMuted; radius: 4 }
							font { family: networkMenu.fontFamily; pixelSize: networkMenu.fontSize - 2 }
							Keys.onReturnPressed: networkMenu.connectToNetwork(modelData.ssid, text)
						}

						Text {
							text: "\uf00c"
							color: networkMenu.colYellow
							font { family: networkMenu.fontFamily; pixelSize: networkMenu.fontSize }
							MouseArea {
								anchors.fill: parent
								cursorShape: Qt.PointingHandCursor
								onClicked: networkMenu.connectToNetwork(modelData.ssid, pwField.text)
							}
						}
					}
				}
			}
		}
	}
}