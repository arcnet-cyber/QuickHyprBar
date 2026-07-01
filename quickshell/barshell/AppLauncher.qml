import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PopupWindow {
	id: launcherPopup
	visible: false
	implicitWidth: 320
	implicitHeight: 420
	color: "transparent"

	property color colBg: "#1a1b26"
	property color colFg: "#a9b1d6"
	property color colMuted: "#444b6a"
	property color colCyan: "#0db9d7"
	property string fontFamily: "JetBrainsMono Nerd Font"
	property int fontSize: 14

	property var anchorWindow: null
	property real barWidth: 50
	property real popupY: 40

	anchor.window: anchorWindow
	anchor.rect.x: barWidth + 8
	anchor.rect.y: popupY

	property var filteredApps: []

	function refreshFilter() {
		const q = searchField.text.toLowerCase()
		filteredApps = DesktopEntries.applications.values.filter(app => {
			return !q || app.name.toLowerCase().includes(q)
		})
	}

	function openLauncher() {
		visible = true
		refreshFilter()
		searchField.forceActiveFocus()
	}

	function closeLauncher() {
		visible = false
	}

	function toggleLauncher() {
		if (visible) {
			closeLauncher()
		} else {
			openLauncher()
		}
	}

	Component.onCompleted: refreshFilter()

	Rectangle {
		anchors.fill: parent
		color: launcherPopup.colBg
		border.color: launcherPopup.colCyan
		border.width: 1
		radius:12

		ColumnLayout {
			anchors.fill: parent
			anchors.margins: 8
			spacing: 6

			TextField {
				id: searchField
				Layout.fillWidth: true
				placeholderText: "Search apps..."
				color: launcherPopup.colFg
				background: Rectangle { color: launcherPopup.colMuted; radius: 4 }
				font { family: launcherPopup.fontFamily; pixelSize: launcherPopup.fontSize }
				onTextChanged: launcherPopup.refreshFilter()
				Keys.onEscapePressed: launcherPopup.closeLauncher()
				Keys.onReturnPressed: {
					if (launcherPopup.filteredApps.length > 0) {
						launcherPopup.filteredApps[0].execute()
						launcherPopup.closeLauncher()
					}
				}
			}

			ListView {
				id: appList
				Layout.fillWidth: true
				Layout.fillHeight: true
				clip: true
				model: launcherPopup.filteredApps
				delegate: Rectangle {
					width: appList.width
					height: 36
					color: appMouse.containsMouse ? launcherPopup.colMuted : "transparent"
					radius: 4
					RowLayout {
						anchors.fill: parent
						anchors.leftMargin: 8
						spacing: 8
						Text {
							text: modelData.name
							color: launcherPopup.colFg
							font { family: launcherPopup.fontFamily; pixelSize: launcherPopup.fontSize }
							elide: Text.ElideRight
							Layout.fillWidth: true
						}
					}
					MouseArea {
						id: appMouse
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: {
							modelData.execute()
							launcherPopup.closeLauncher()
						}
					}
				}
			}
		}
	}
}