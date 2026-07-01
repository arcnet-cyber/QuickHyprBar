import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PopupWindow {
	id: btMenu
	visible: false
	implicitWidth: 320
	implicitHeight: 420
	
	// Make the popup background transparent
	color: "transparent"

	property color colBg: "#1a1b26"
	property color colFg: "#a9b1d6"
	property color colMuted: "#444b6a"
	property color colCyan: "#7aa2f7"
	property color colYellow: "#e0af68"
	property color colRed: "#f7768e"
	property color colGreen: "#9ece6a"
	property string fontFamily: "JetBrainsMono Nerd Font"
	property int fontSize: 14

	property var anchorWindow: null
	property real barWidth: 50
	property real popupY: 40

	anchor.window: anchorWindow
	anchor.rect.x: barWidth + 8
	anchor.rect.y: popupY

	property var devices: []
	property bool powered: false
	property bool scanning: false
	property bool refreshing: false
	property var _scanBuffer: []
	property int infoIndex: 0
	property string expandedDevice: ""

	// --- Pairing state ---
	property bool pairingInProgress: false
	property bool awaitingConfirm: false
	property string confirmPasskey: ""
	property string pendingMac: ""
	property bool sessionReady: false
	property bool sessionStarting: false
	
	// --- Command queue ---
	property var commandQueue: []
	property bool processingQueue: false
	property bool agentReady: false
	
	// --- Passkey buffer for faster detection ---
	property string outputBuffer: ""
	property bool passkeyDetected: false

	function toggleMenu() {
		if (visible) {
			closeMenu()
		} else {
			openMenu()
		}
	}

	function openMenu() {
		visible = true
		refreshDevices()
		checkPower()
		
		// Reset state
		sessionReady = false
		sessionStarting = false
		agentReady = false
		commandQueue = []
		processingQueue = false
		pairingInProgress = false
		awaitingConfirm = false
		confirmPasskey = ""
		expandedDevice = ""
		outputBuffer = ""
		passkeyDetected = false
		
		// Start session with proper initialization
		startBluetoothSession()
	}

	function closeMenu() {
		visible = false
		sessionReady = false
		sessionStarting = false
		agentReady = false
		commandQueue = []
		processingQueue = false
		pairingInProgress = false
		awaitingConfirm = false
		confirmPasskey = ""
		refreshing = false
		expandedDevice = ""
		outputBuffer = ""
		passkeyDetected = false
		pairSession.running = false
	}

	function startBluetoothSession() {
		if (sessionStarting) return
		sessionStarting = true
		pairSession.running = false
		pairSession.running = true
	}

	function checkPower() {
		powerCheckProc.running = true
	}

	function togglePower() {
		if (powered) {
			powerOffProc.running = true
		} else {
			powerOnProc.running = true
		}
	}

	function startScan() {
		if (scanning) return
		scanning = true
		scanOnProc.running = true
	}

	function refreshDevices() {
		if (refreshing) return
		refreshing = true
		listProc.running = true
	}

	function toggleDevice(deviceMac) {
		if (expandedDevice === deviceMac) {
			expandedDevice = ""
		} else {
			expandedDevice = deviceMac
		}
	}

	// --- Queue or execute command ---
	function sendCommand(cmd, retryCount = 0) {
		if (sessionReady && agentReady) {
			pairSession.write(cmd + "\n")
			return true
		} else {
			commandQueue.push({cmd: cmd, retries: retryCount})
			if (!processingQueue) {
				processQueue()
			}
			return false
		}
	}

	function processQueue() {
		if (processingQueue || commandQueue.length === 0) return
		if (!sessionReady || !agentReady) {
			sessionWaitTimer.start()
			return
		}
		
		processingQueue = true
		const batch = commandQueue.splice(0)
		for (const item of batch) {
			pairSession.write(item.cmd + "\n")
			if (batch.length > 1) {
				commandDelayTimer.start()
				processingQueue = false
				return
			}
		}
		processingQueue = false
	}

	Timer {
		id: commandDelayTimer
		interval: 200
		repeat: false
		onTriggered: {
			btMenu.processingQueue = false
			btMenu.processQueue()
		}
	}

	Timer {
		id: sessionWaitTimer
		interval: 100
		repeat: true
		onTriggered: {
			if (btMenu.sessionReady && btMenu.agentReady) {
				stop()
				btMenu.processQueue()
			}
			if (repeatCount > 30) {
				stop()
				console.warn("Session initialization timeout, restarting...")
				btMenu.sessionReady = false
				btMenu.agentReady = false
				btMenu.sessionStarting = false
				btMenu.startBluetoothSession()
			}
		}
	}

	// --- Power status ---
	Process {
		id: powerCheckProc
		command: ["bluetoothctl", "show"]
		stdout: SplitParser {
			splitMarker: "\n"
			onRead: (line) => {
				if (line.includes("Powered:")) {
					btMenu.powered = line.includes("yes")
				}
			}
		}
		stderr: SplitParser {
			splitMarker: "\n"
			onRead: (line) => console.warn("powerCheck stderr:", line)
		}
	}

	Process {
		id: powerOnProc
		command: ["bluetoothctl", "power", "on"]
		onExited: {
			checkPower()
			refreshDevices()
		}
		stderr: SplitParser {
			splitMarker: "\n"
			onRead: (line) => console.warn("powerOn stderr:", line)
		}
	}

	Process {
		id: powerOffProc
		command: ["bluetoothctl", "power", "off"]
		onExited: {
			checkPower()
			refreshDevices()
		}
		stderr: SplitParser {
			splitMarker: "\n"
			onRead: (line) => console.warn("powerOff stderr:", line)
		}
	}

	// --- Scan ---
	Process {
		id: scanOnProc
		command: ["bluetoothctl", "--timeout", "20", "scan", "on"]
		onExited: {
			btMenu.scanning = false
			btMenu.refreshDevices()
		}
		stderr: SplitParser {
			splitMarker: "\n"
			onRead: (line) => {
				console.warn("scan stderr:", line)
				btMenu.scanning = false
			}
		}
	}

	// --- Bluetooth session with faster passkey detection ---
	Process {
		id: pairSession
		command: ["bluetoothctl"]
		running: false
		stdinEnabled: true

		stdout: SplitParser {
			splitMarker: "\n"
			onRead: (line) => {
				// Debug output
				console.log("btctl:", line)
				
				// Accumulate buffer for faster matching
				btMenu.outputBuffer += line + "\n"
				
				// Check for passkey in the buffer immediately
				if (!btMenu.passkeyDetected && btMenu.outputBuffer.includes("Confirm passkey")) {
					const match = btMenu.outputBuffer.match(/passkey\s+(\d+)/)
					if (match) {
						btMenu.confirmPasskey = match[1]
						btMenu.awaitingConfirm = true
						btMenu.passkeyDetected = true
						autoConfirmTimer.start()
						btMenu.outputBuffer = ""
						console.log("Passkey detected:", btMenu.confirmPasskey)
						return
					}
				}
				
				// If buffer gets too large, clear it
				if (btMenu.outputBuffer.length > 1000) {
					btMenu.outputBuffer = btMenu.outputBuffer.substring(btMenu.outputBuffer.length - 500)
				}
				
				// Session initialization
				if (!btMenu.agentReady && line.includes("Agent registered")) {
					pairSession.write("default-agent\n")
					pairSession.write("agent NoInputNoOutput\n")
					btMenu.agentReady = true
					btMenu.sessionReady = true
					btMenu.sessionStarting = false
					btMenu.processQueue()
					return
				}
				
				if (btMenu.agentReady && !btMenu.sessionReady && line.includes("Default agent request successful")) {
					btMenu.sessionReady = true
					btMenu.sessionStarting = false
					btMenu.processQueue()
					return
				}
				
				// Only process other messages after passkey is handled
				if (btMenu.passkeyDetected) return
				
				if (line.includes("Pairing successful")) {
					btMenu.awaitingConfirm = false
					btMenu.confirmPasskey = ""
					btMenu.passkeyDetected = false
					autoConfirmTimer.stop()
					
					btMenu.pairingInProgress = false
					clearPairingTimer.restart()
					btMenu.refreshDevices()
					return
				}
				
				if (line.includes("Failed to pair") || line.includes("Pairing failed") || line.includes("Authentication failed")) {
					btMenu.awaitingConfirm = false
					btMenu.confirmPasskey = ""
					btMenu.pairingInProgress = false
					btMenu.passkeyDetected = false
					autoConfirmTimer.stop()
					errorMessage = "Pairing failed"
					errorTimer.start()
					btMenu.refreshDevices()
					return
				}
				
				if (line.includes("Connection successful")) {
					btMenu.refreshDevices()
					return
				}
				
				if (line.includes("Failed to connect") || line.includes("Connection refused") || line.includes("Connection timeout")) {
					console.warn("Connection failed:", line)
					errorMessage = "Connection failed"
					errorTimer.start()
					btMenu.refreshDevices()
					return
				}
				
				if (line.includes("Successful disconnected")) {
					btMenu.refreshDevices()
					return
				}
				
				if (line.includes("Device") && line.includes("removed")) {
					btMenu.refreshDevices()
					return
				}
				
				if (line.includes("Connected: yes") || line.includes("Connected: no")) {
					btMenu.refreshDevices()
					return
				}
				
				if (line.includes("Device") && line.includes("not available")) {
					console.warn("Device not available:", line)
					btMenu.refreshDevices()
					return
				}
			}
		}

		stderr: SplitParser {
			splitMarker: "\n"
			onRead: (line) => {
				console.warn("btctl stderr:", line)
				if (line.includes("org.bluez.Error") || line.includes("Permission denied")) {
					btMenu.sessionReady = false
					btMenu.agentReady = false
					btMenu.pairingInProgress = false
					btMenu.awaitingConfirm = false
					btMenu.passkeyDetected = false
					errorMessage = "Error: " + line
					errorTimer.start()
					restartTimer.start()
				}
			}
		}

		onStarted: {
			write("agent NoInputNoOutput\n")
			write("default-agent\n")
		}

		onExited: {
			btMenu.sessionReady = false
			btMenu.agentReady = false
			btMenu.sessionStarting = false
			btMenu.awaitingConfirm = false
			btMenu.pairingInProgress = false
			btMenu.confirmPasskey = ""
			btMenu.commandQueue = []
			btMenu.processingQueue = false
			btMenu.passkeyDetected = false
			btMenu.outputBuffer = ""
			
			if (btMenu.visible) {
				restartTimer.start()
			}
		}
	}

	Timer {
		id: restartTimer
		interval: 500
		repeat: false
		onTriggered: {
			if (btMenu.visible) {
				btMenu.sessionStarting = false
				btMenu.startBluetoothSession()
			}
		}
	}

	Timer {
		id: autoConfirmTimer
		interval: 5000
		repeat: false
		onTriggered: {
			if (btMenu.awaitingConfirm) {
				console.warn("Passkey confirmation timed out, auto-confirming...")
				btMenu.confirmPasskeyYes()
			}
		}
	}

	Timer {
		id: clearPairingTimer
		interval: 1500
		repeat: false
		onTriggered: {
			btMenu.pairingInProgress = false
			btMenu.refreshDevices()
		}
	}

	property string errorMessage: ""
	
	Timer {
		id: errorTimer
		interval: 3000
		repeat: false
		onTriggered: {
			btMenu.errorMessage = ""
		}
	}

	function confirmPasskeyYes() {
		awaitingConfirm = false
		confirmPasskey = ""
		passkeyDetected = false
		autoConfirmTimer.stop()
		pairSession.write("yes\n")
	}

	function confirmPasskeyNo() {
		awaitingConfirm = false
		pairingInProgress = false
		confirmPasskey = ""
		passkeyDetected = false
		autoConfirmTimer.stop()
		pairSession.write("no\n")
	}

	function cancelPairing() {
		awaitingConfirm = false
		pairingInProgress = false
		confirmPasskey = ""
		passkeyDetected = false
		autoConfirmTimer.stop()
		pairSession.write("cancel\n")
	}

	function connectDevice(mac) {
		sendCommand("connect " + mac)
		expandedDevice = ""
	}

	function disconnectDevice(mac) {
		sendCommand("disconnect " + mac)
		expandedDevice = ""
	}

	function pairDevice(mac) {
		if (pairingInProgress) return
		
		pendingMac = mac
		pairingInProgress = true
		awaitingConfirm = false
		confirmPasskey = ""
		passkeyDetected = false
		outputBuffer = ""
		autoConfirmTimer.stop()
		
		if (!sessionReady || !agentReady) {
			commandQueue.push({cmd: "pair " + mac, retries: 0})
			processQueue()
		} else {
			sendCommand("pair " + mac)
		}
		expandedDevice = ""
	}

	function forgetDevice(mac) {
		sendCommand("remove " + mac)
		expandedDevice = ""
		refreshDevices()
	}

	// --- Device list ---
	Process {
		id: listProc
		command: ["bluetoothctl", "devices"]

		stdout: SplitParser {
			splitMarker: "\n"
			onRead: (line) => {
				if (line.trim()) {
					btMenu._scanBuffer.push(line)
				}
			}
		}

		stderr: SplitParser {
			splitMarker: "\n"
			onRead: (line) => {
				console.warn("listProc stderr:", line)
				btMenu.refreshing = false
			}
		}

		onStarted: {
			btMenu._scanBuffer = []
		}

		onExited: (exitCode) => {
			const buf = btMenu._scanBuffer
			const parsed = []
			for (const line of buf) {
				if (!line || !line.startsWith("Device")) continue
				const parts = line.split(" ")
				const mac = parts[1]
				const name = parts.slice(2).join(" ")
				if (!mac) continue
				parsed.push({ mac: mac, name: name || mac, connected: false, trusted: false })
			}
			btMenu.devices = parsed
			btMenu.refreshing = false
			
			if (parsed.length > 0) {
				btMenu.infoIndex = 0
				btMenu.checkNextInfo()
			}
		}
	}

	function checkNextInfo() {
		if (infoIndex >= devices.length) {
			return
		}
		infoProc.command = ["bluetoothctl", "info", devices[infoIndex].mac]
		infoProc.running = true
	}

	Process {
		id: infoProc
		property int currentIndex: 0
		
		onStarted: {
			currentIndex = btMenu.infoIndex
		}
		
		stdout: SplitParser {
			splitMarker: "\n"
			onRead: (line) => {
				const updated = btMenu.devices.slice()
				if (!updated[infoProc.currentIndex]) return
				
				if (line.includes("Connected:") && line.includes("yes")) {
					updated[infoProc.currentIndex].connected = true
				}
				if (line.includes("Trusted:") && line.includes("yes")) {
					updated[infoProc.currentIndex].trusted = true
				}
				btMenu.devices = updated
			}
		}
		
		stderr: SplitParser {
			splitMarker: "\n"
			onRead: (line) => console.warn("infoProc stderr:", line)
		}
		
		onExited: {
			btMenu.infoIndex++
			if (btMenu.infoIndex < btMenu.devices.length) {
				btMenu.checkNextInfo()
			}
		}
	}

	// Wrap everything in a Rectangle for rounded corners and border
	Rectangle {
		id: wrapper
		anchors.fill: parent
		color: colBg
		radius: 12
		border.width: 1
		border.color: colCyan
		clip: true

		ColumnLayout {
			anchors.fill: parent
			anchors.margins: 8
			spacing: 6

			RowLayout {
				Layout.fillWidth: true
				Text {
					text: "Bluetooth"
					color: btMenu.colFg
					font { family: btMenu.fontFamily; pixelSize: btMenu.fontSize; bold: true }
					Layout.fillWidth: true
				}
				Text {
					text: btMenu.powered ? "On" : "Off"
					color: btMenu.powered ? btMenu.colCyan : btMenu.colMuted
					font { family: btMenu.fontFamily; pixelSize: btMenu.fontSize - 2; bold: true }
					MouseArea {
						anchors.fill: parent
						cursorShape: Qt.PointingHandCursor
						onClicked: btMenu.togglePower()
					}
				}
			}

			// --- Error message ---
			Text {
				Layout.fillWidth: true
				visible: btMenu.errorMessage !== ""
				text: btMenu.errorMessage
				color: btMenu.colRed
				font { family: btMenu.fontFamily; pixelSize: btMenu.fontSize - 2 }
				wrapMode: Text.WordWrap
			}

			// --- Pairing status ---
			Rectangle {
				Layout.fillWidth: true
				visible: btMenu.pairingInProgress
				height: btMenu.awaitingConfirm ? 72 : 32
				radius: 4
				color: btMenu.colMuted
				border.width: 1
				border.color: btMenu.colCyan

				ColumnLayout {
					anchors.fill: parent
					anchors.margins: 8
					spacing: 6

					Text {
						text: btMenu.awaitingConfirm
							? "Confirm passkey: " + btMenu.confirmPasskey
							: "Pairing..."
						color: btMenu.colFg
						font { family: btMenu.fontFamily; pixelSize: btMenu.fontSize - 2; bold: true }
					}

					RowLayout {
						visible: btMenu.awaitingConfirm
						spacing: 12

						Text {
							text: "Yes"
							color: btMenu.colCyan
							font { family: btMenu.fontFamily; pixelSize: btMenu.fontSize - 2; bold: true }
							MouseArea {
								anchors.fill: parent
								cursorShape: Qt.PointingHandCursor
								onClicked: btMenu.confirmPasskeyYes()
							}
						}

						Text {
							text: "No"
							color: btMenu.colYellow
							font { family: btMenu.fontFamily; pixelSize: btMenu.fontSize - 2; bold: true }
							MouseArea {
								anchors.fill: parent
								cursorShape: Qt.PointingHandCursor
								onClicked: btMenu.confirmPasskeyNo()
							}
						}

						Text {
							text: "Cancel"
							color: btMenu.colMuted
							font { family: btMenu.fontFamily; pixelSize: btMenu.fontSize - 2 }
							MouseArea {
								anchors.fill: parent
								cursorShape: Qt.PointingHandCursor
								onClicked: btMenu.cancelPairing()
							}
						}
					}
				}
			}

			RowLayout {
				Layout.fillWidth: true
				spacing: 6

				Rectangle {
					Layout.fillWidth: true
					height: 28
					radius: 4
					color: (btMenu.scanning || btMenu.refreshing) ? btMenu.colMuted : "transparent"
					border.width: 1
					border.color: (btMenu.scanning || btMenu.refreshing) ? btMenu.colCyan : btMenu.colMuted

					Text {
						anchors.centerIn: parent
						text: btMenu.scanning ? "Scanning..." : (btMenu.refreshing ? "Refreshing..." : "Scan for devices")
						color: (btMenu.scanning || btMenu.refreshing) ? btMenu.colCyan : btMenu.colFg
						font { family: btMenu.fontFamily; pixelSize: btMenu.fontSize - 2 }
					}

					MouseArea {
						anchors.fill: parent
						cursorShape: Qt.PointingHandCursor
						enabled: !btMenu.scanning && !btMenu.refreshing
						onClicked: btMenu.startScan()
					}
				}

				Text {
					id: refreshIcon
					text: "\uf021"
					property bool hovered: false
					color: hovered ? btMenu.colCyan : btMenu.colMuted
					font { family: btMenu.fontFamily; pixelSize: btMenu.fontSize }
					MouseArea {
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onEntered: refreshIcon.hovered = true
						onExited: refreshIcon.hovered = false
						onClicked: btMenu.refreshDevices()
					}
				}
			}

			// --- Device List with Dropdown ---
			ListView {
				id: devList
				Layout.fillWidth: true
				Layout.fillHeight: true
				clip: true
				model: btMenu.devices
				spacing: 2

				delegate: Column {
					width: devList.width
					spacing: 0

					// Main device row (always visible)
					Rectangle {
						width: parent.width
						height: 36
						radius: 4
						color: btMenu.expandedDevice === modelData.mac ? Qt.rgba(0.3, 0.3, 0.4, 0.3) : "transparent"
						
						MouseArea {
							anchors.fill: parent
							onClicked: btMenu.toggleDevice(modelData.mac)
						}

						RowLayout {
							anchors.fill: parent
							anchors.leftMargin: 8
							anchors.rightMargin: 8
							spacing: 6

							Text {
								text: modelData.connected ? "\uf293" : "\uf294"
								color: modelData.connected ? btMenu.colCyan : btMenu.colFg
								font { family: btMenu.fontFamily; pixelSize: btMenu.fontSize }
							}

							Text {
								text: modelData.name
								color: btMenu.colFg
								font { family: btMenu.fontFamily; pixelSize: btMenu.fontSize }
								elide: Text.ElideRight
								Layout.fillWidth: true
							}

							Text {
								text: btMenu.expandedDevice === modelData.mac ? "\uf106" : "\uf107"
								color: btMenu.colMuted
								font { family: btMenu.fontFamily; pixelSize: btMenu.fontSize }
							}
						}
					}

					// Dropdown menu (shown when expanded)
					Rectangle {
						width: parent.width
						height: btMenu.expandedDevice === modelData.mac ? 36 : 0
						radius: 4
						color: Qt.rgba(0.2, 0.2, 0.3, 0.15)
						clip: true
						
						Behavior on height {
							NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
						}

						RowLayout {
							anchors.fill: parent
							anchors.leftMargin: 8
							anchors.rightMargin: 8
							spacing: 16
							visible: btMenu.expandedDevice === modelData.mac

							// Forget button (first)
							Text {
								text: "Forget"
								color: btMenu.colRed
								font { family: btMenu.fontFamily; pixelSize: btMenu.fontSize - 2 }
								MouseArea {
									anchors.fill: parent
									cursorShape: Qt.PointingHandCursor
									onClicked: btMenu.forgetDevice(modelData.mac)
								}
							}

							// Connect/Disconnect button (second)
							Text {
								text: modelData.connected ? "Disconnect" : "Connect"
								color: modelData.connected ? btMenu.colYellow : btMenu.colCyan
								font { family: btMenu.fontFamily; pixelSize: btMenu.fontSize - 2 }
								MouseArea {
									anchors.fill: parent
									cursorShape: Qt.PointingHandCursor
									onClicked: {
										if (modelData.connected) {
											btMenu.disconnectDevice(modelData.mac)
										} else {
											btMenu.connectDevice(modelData.mac)
										}
									}
								}
							}

							// Pair button (third)
							Text {
								text: modelData.trusted ? "Paired ✓" : "Pair"
								color: modelData.trusted ? btMenu.colMuted : (btMenu.pairingInProgress ? btMenu.colMuted : btMenu.colGreen)
								font { family: btMenu.fontFamily; pixelSize: btMenu.fontSize - 2 }
								MouseArea {
									anchors.fill: parent
									cursorShape: (btMenu.pairingInProgress || modelData.trusted) ? Qt.ArrowCursor : Qt.PointingHandCursor
									enabled: !btMenu.pairingInProgress && !modelData.trusted
									onClicked: btMenu.pairDevice(modelData.mac)
								}
							}
						}
					}
				}
			}
		}
	}
}