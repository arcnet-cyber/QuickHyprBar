import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PopupWindow {
	id: soundMenu
	visible: false
	implicitWidth: 260
	implicitHeight: 180
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

	property real outVolume: 0
	property bool outMuted: false
	property real inVolume: 0
	property bool inMuted: false

	function toggleMenu() {
		if (visible) {
			closeMenu()
		} else {
			openMenu()
		}
	}

	function openMenu() {
		visible = true
		refreshAll()
	}

	function closeMenu() {
		visible = false
	}

	function refreshAll() {
		outVolProc.running = true
		inVolProc.running = true
	}

	function setOutVolume(val) {
		const clamped = Math.max(0, Math.min(1.5, val))
		setOutProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", clamped.toFixed(2)]
		setOutProc.running = true
	}

	function setInVolume(val) {
		const clamped = Math.max(0, Math.min(1.5, val))
		setInProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", clamped.toFixed(2)]
		setInProc.running = true
	}

	function toggleOutMute() {
		toggleOutMuteProc.running = true
	}

	function toggleInMute() {
		toggleInMuteProc.running = true
	}

	function parseVolumeLine(line) {
		const match = line.match(/Volume:\s*([\d.]+)/)
		const vol = match ? parseFloat(match[1]) : 0
		const muted = line.includes("[MUTED]")
		return { vol: vol, muted: muted }
	}

	Process {
		id: outVolProc
		command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
		stdout: SplitParser {
			splitMarker: "\n"
			onRead: (line) => {
				if (!line.includes("Volume:")) return
				const parsed = soundMenu.parseVolumeLine(line)
				soundMenu.outVolume = parsed.vol
				soundMenu.outMuted = parsed.muted
			}
		}
	}

	Process {
		id: inVolProc
		command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
		stdout: SplitParser {
			splitMarker: "\n"
			onRead: (line) => {
				if (!line.includes("Volume:")) return
				const parsed = soundMenu.parseVolumeLine(line)
				soundMenu.inVolume = parsed.vol
				soundMenu.inMuted = parsed.muted
			}
		}
	}

	Process {
		id: setOutProc
		onExited: soundMenu.refreshAll()
	}

	Process {
		id: setInProc
		onExited: soundMenu.refreshAll()
	}

	Process {
		id: toggleOutMuteProc
		command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
		onExited: soundMenu.refreshAll()
	}

	Process {
		id: toggleInMuteProc
		command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]
		onExited: soundMenu.refreshAll()
	}

	Timer {
		interval: 3000
		running: soundMenu.visible
		repeat: true
		onTriggered: soundMenu.refreshAll()
	}

	Rectangle {
		anchors.fill: parent
		color: soundMenu.colBg
		border.color: soundMenu.colBlue
		border.width: 1
		radius: 12

		ColumnLayout {
			anchors.fill: parent
			anchors.margins: 12
			spacing: 14

			// --- Output ---
			RowLayout {
				Layout.fillWidth: true
				spacing: 8

				Text {
					text: soundMenu.outMuted ? "\uf6a9" : "\uf028"
					color: soundMenu.outMuted ? soundMenu.colYellow : soundMenu.colCyan
					font { family: soundMenu.fontFamily; pixelSize: soundMenu.fontSize + 2 }
					MouseArea {
						anchors.fill: parent
						cursorShape: Qt.PointingHandCursor
						onClicked: soundMenu.toggleOutMute()
					}
				}

				Text {
					text: "Output"
					color: soundMenu.colFg
					font { family: soundMenu.fontFamily; pixelSize: soundMenu.fontSize - 2 }
					Layout.preferredWidth: 44
				}

				Item {
					id: outSliderItem
					Layout.fillWidth: true
					height: 20
					property real sliderValue: soundMenu.outVolume
					property real sliderMin: 0
					property real sliderMax: 1.5

					Rectangle {
						id: outTrack
						anchors.verticalCenter: parent.verticalCenter
						width: parent.width
						height: 4
						radius: 2
						color: soundMenu.colMuted
						Rectangle {
							width: Math.max(0, Math.min(1, (outSliderItem.sliderValue - outSliderItem.sliderMin) / (outSliderItem.sliderMax - outSliderItem.sliderMin))) * parent.width
							height: parent.height
							radius: 2
							color: soundMenu.colCyan
						}
					}

					Rectangle {
						width: 14
						height: 14
						radius: 7
						color: soundMenu.colCyan
						anchors.verticalCenter: outTrack.verticalCenter
						x: Math.max(0, Math.min(1, (outSliderItem.sliderValue - outSliderItem.sliderMin) / (outSliderItem.sliderMax - outSliderItem.sliderMin))) * (outSliderItem.width - width)
					}

					MouseArea {
						anchors.fill: parent
						anchors.margins: -6
						onPressed: (mouse) => {
							const ratio = Math.max(0, Math.min(1, mouse.x / outSliderItem.width))
							outSliderItem.sliderValue = outSliderItem.sliderMin + ratio * (outSliderItem.sliderMax - outSliderItem.sliderMin)
						}
						onPositionChanged: (mouse) => {
							if (!pressed) return
							const ratio = Math.max(0, Math.min(1, mouse.x / outSliderItem.width))
							outSliderItem.sliderValue = outSliderItem.sliderMin + ratio * (outSliderItem.sliderMax - outSliderItem.sliderMin)
						}
						onReleased: soundMenu.setOutVolume(outSliderItem.sliderValue)
					}
				}

				Text {
					text: Math.round(soundMenu.outVolume * 100) + "%"
					color: soundMenu.colMuted
					font { family: soundMenu.fontFamily; pixelSize: soundMenu.fontSize - 3 }
					Layout.preferredWidth: 36
				}
			}

			// --- Input ---
			RowLayout {
				Layout.fillWidth: true
				spacing: 8

				Text {
					text: soundMenu.inMuted ? "\uf131" : "\uf130"
					color: soundMenu.inMuted ? soundMenu.colYellow : soundMenu.colCyan
					font { family: soundMenu.fontFamily; pixelSize: soundMenu.fontSize + 2 }
					MouseArea {
						anchors.fill: parent
						cursorShape: Qt.PointingHandCursor
						onClicked: soundMenu.toggleInMute()
					}
				}

				Text {
					text: "Input"
					color: soundMenu.colFg
					font { family: soundMenu.fontFamily; pixelSize: soundMenu.fontSize - 2 }
					Layout.preferredWidth: 44
				}

				Item {
					id: inSliderItem
					Layout.fillWidth: true
					height: 20
					property real sliderValue: soundMenu.inVolume
					property real sliderMin: 0
					property real sliderMax: 1.5

					Rectangle {
						id: inTrack
						anchors.verticalCenter: parent.verticalCenter
						width: parent.width
						height: 4
						radius: 2
						color: soundMenu.colMuted
						Rectangle {
							width: Math.max(0, Math.min(1, (inSliderItem.sliderValue - inSliderItem.sliderMin) / (inSliderItem.sliderMax - inSliderItem.sliderMin))) * parent.width
							height: parent.height
							radius: 2
							color: soundMenu.colCyan
						}
					}

					Rectangle {
						width: 14
						height: 14
						radius: 7
						color: soundMenu.colCyan
						anchors.verticalCenter: inTrack.verticalCenter
						x: Math.max(0, Math.min(1, (inSliderItem.sliderValue - inSliderItem.sliderMin) / (inSliderItem.sliderMax - inSliderItem.sliderMin))) * (inSliderItem.width - width)
					}

					MouseArea {
						anchors.fill: parent
						anchors.margins: -6
						onPressed: (mouse) => {
							const ratio = Math.max(0, Math.min(1, mouse.x / inSliderItem.width))
							inSliderItem.sliderValue = inSliderItem.sliderMin + ratio * (inSliderItem.sliderMax - inSliderItem.sliderMin)
						}
						onPositionChanged: (mouse) => {
							if (!pressed) return
							const ratio = Math.max(0, Math.min(1, mouse.x / inSliderItem.width))
							inSliderItem.sliderValue = inSliderItem.sliderMin + ratio * (inSliderItem.sliderMax - inSliderItem.sliderMin)
						}
						onReleased: soundMenu.setInVolume(inSliderItem.sliderValue)
					}
				}

				Text {
					text: Math.round(soundMenu.inVolume * 100) + "%"
					color: soundMenu.colMuted
					font { family: soundMenu.fontFamily; pixelSize: soundMenu.fontSize - 3 }
					Layout.preferredWidth: 36
				}
			}
		}
	}
}