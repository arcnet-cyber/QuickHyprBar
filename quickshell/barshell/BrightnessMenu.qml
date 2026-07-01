import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PopupWindow {
	id: brightMenu
	visible: false
	implicitWidth: 240
	implicitHeight: 90
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

	property real brightness: 1.0

	function toggleMenu() {
		if (visible) {
			closeMenu()
		} else {
			openMenu()
		}
	}

	function openMenu() {
		visible = true
		refresh()
	}

	function closeMenu() {
		visible = false
	}

	function refresh() {
		getProc.running = true
	}

	function setBrightness(val) {
		const pct = Math.round(Math.max(5, Math.min(100, val * 100)))
		setProc.command = ["brightnessctl", "set", pct + "%"]
		setProc.running = true
	}

	Process {
		id: getProc
		command: ["brightnessctl", "info"]
		property int current: 0
		property int max: 1
		stdout: SplitParser {
			splitMarker: "\n"
			onRead: (line) => {
				const curMatch = line.match(/Current brightness:\s*(\d+)/)
				const maxMatch = line.match(/Max brightness:\s*(\d+)/)
				if (curMatch) getProc.current = parseInt(curMatch[1])
				if (maxMatch) getProc.max = parseInt(maxMatch[1])
			}
		}
		onExited: {
			if (getProc.max > 0) {
				brightMenu.brightness = getProc.current / getProc.max
			}
		}
	}

	Process {
		id: setProc
		onExited: brightMenu.refresh()
	}

	Rectangle {
		anchors.fill: parent
		color: brightMenu.colBg
		border.color: brightMenu.colBlue
		border.width: 1
		radius: 12

		ColumnLayout {
			anchors.fill: parent
			anchors.margins: 12
			spacing: 8

			Text {
				text: "Brightness"
				color: brightMenu.colFg
				font { family: brightMenu.fontFamily; pixelSize: brightMenu.fontSize; bold: true }
			}

			RowLayout {
				Layout.fillWidth: true
				spacing: 8

				Text {
					text: "\uf185"
					color: brightMenu.colYellow
					font { family: brightMenu.fontFamily; pixelSize: brightMenu.fontSize + 2 }
				}

				Item {
					id: brightSliderItem
					Layout.fillWidth: true
					height: 20
					property real sliderValue: brightMenu.brightness

					Rectangle {
						id: brightTrack
						anchors.verticalCenter: parent.verticalCenter
						width: parent.width
						height: 4
						radius: 2
						color: brightMenu.colMuted
						Rectangle {
							width: Math.max(0, Math.min(1, brightSliderItem.sliderValue)) * parent.width
							height: parent.height
							radius: 2
							color: brightMenu.colYellow
						}
					}

					Rectangle {
						width: 14
						height: 14
						radius: 7
						color: brightMenu.colYellow
						anchors.verticalCenter: brightTrack.verticalCenter
						x: Math.max(0, Math.min(1, brightSliderItem.sliderValue)) * (brightSliderItem.width - width)
					}

					MouseArea {
						anchors.fill: parent
						anchors.margins: -6
						onPressed: (mouse) => {
							brightSliderItem.sliderValue = Math.max(0.05, Math.min(1, mouse.x / brightSliderItem.width))
						}
						onPositionChanged: (mouse) => {
							if (!pressed) return
							brightSliderItem.sliderValue = Math.max(0.05, Math.min(1, mouse.x / brightSliderItem.width))
						}
						onReleased: brightMenu.setBrightness(brightSliderItem.sliderValue)
					}
				}

				Text {
					text: Math.round(brightMenu.brightness * 100) + "%"
					color: brightMenu.colMuted
					font { family: brightMenu.fontFamily; pixelSize: brightMenu.fontSize - 3 }
					Layout.preferredWidth: 36
				}
			}
		}
	}
}