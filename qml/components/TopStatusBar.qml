import QtQuick 2.11
import QtQuick.Controls 2.4
import "../common"

Rectangle {
    id: root
    width: 800
    height: 45
    color: Theme.mainBg

    // --- 中间：实时时间 ---
    Text {
        id: timeText
        anchors.centerIn: parent
        color: Theme.textMain
        font.pixelSize: Theme.sizeSubTitle
        font.bold: true
        font.family: "Monospace"

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                var d = new Date()
                timeText.text = Qt.formatDateTime(d, "hh:mm:ss")
            }
            Component.onCompleted: {
                var d = new Date()
                timeText.text = Qt.formatDateTime(d, "hh:mm:ss")
            }
        }
    }

    // --- 左侧：Web状态 ---
    Item {
        id: webArea
        anchors.left: parent.left
        anchors.leftMargin: 15
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height

        Rectangle {
            width: 10
            height: 10
            radius: 5
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: core.isNetworkConnected ? Theme.accentGreen : Theme.accentRed

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.0; duration: 1500; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.0; to: 1.0; duration: 1500; easing.type: Easing.InOutQuad }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: core.isNetworkConnected ? "Web在线可用" : "Web无法访问"
            color: core.isNetworkConnected ? Theme.accentGreen : Theme.accentRed
            font.pixelSize: Theme.sizeStatusBar
            font.bold: true
        }
    }

    // --- 右侧：警告状态 ---
    Item {
        id: sensorArea
        anchors.right: parent.right
        anchors.rightMargin: 15
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        width: 120

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 75
            anchors.verticalCenter: parent.verticalCenter
            text: "状态"
            color: Theme.textSecondary
            font.pixelSize: Theme.sizeStatusBar
        }

        Rectangle {
            width: 8
            height: 8
            radius: 4
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: "#666666"
        }

        Rectangle {
            width: 8
            height: 8
            radius: 4
            anchors.right: parent.right
            anchors.rightMargin: 13
            anchors.verticalCenter: parent.verticalCenter
            color: {
                var states = core.sensorAlarmStates
                if (states.length > 4) {
                    var state = states[4]
                    if (state === 0) return Theme.accentGreen
                    if (state === 1) return Theme.accentRed
                }
                return "#666666"
            }
        }

        Rectangle {
            width: 8
            height: 8
            radius: 4
            anchors.right: parent.right
            anchors.rightMargin: 26
            anchors.verticalCenter: parent.verticalCenter
            color: {
                var states = core.sensorAlarmStates
                if (states.length > 3) {
                    var state = states[3]
                    if (state === 0) return Theme.accentGreen
                    if (state === 1) return Theme.accentRed
                }
                return "#666666"
            }
        }

        Rectangle {
            width: 8
            height: 8
            radius: 4
            anchors.right: parent.right
            anchors.rightMargin: 39
            anchors.verticalCenter: parent.verticalCenter
            color: {
                var states = core.sensorAlarmStates
                if (states.length > 2) {
                    var state = states[2]
                    if (state === 0) return Theme.accentGreen
                    if (state === 1) return Theme.accentRed
                }
                return "#666666"
            }
        }

        Rectangle {
            width: 8
            height: 8
            radius: 4
            anchors.right: parent.right
            anchors.rightMargin: 52
            anchors.verticalCenter: parent.verticalCenter
            color: {
                var states = core.sensorAlarmStates
                if (states.length > 1) {
                    var state = states[1]
                    if (state === 0) return Theme.accentGreen
                    if (state === 1) return Theme.accentRed
                }
                return "#666666"
            }
        }

        Rectangle {
            width: 8
            height: 8
            radius: 4
            anchors.right: parent.right
            anchors.rightMargin: 65
            anchors.verticalCenter: parent.verticalCenter
            color: {
                var states = core.sensorAlarmStates
                if (states.length > 0) {
                    var state = states[0]
                    if (state === 0) return Theme.accentGreen
                    if (state === 1) return Theme.accentRed
                }
                return "#666666"
            }
        }
    }
    
    // 点击区域 - 覆盖整个右侧
    MouseArea {
        anchors.right: parent.right
        anchors.rightMargin: 0
        anchors.verticalCenter: parent.verticalCenter
        width: sensorArea.width + 15
        height: parent.height
        onClicked: statusPopup.open()
    }

    // --- 下拉菜单 ---
    Popup {
        id: statusPopup
        width: 280
        height: 260
        modal: false
        focus: false
        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
        
        x: root.width - width - 15
        y: root.height
        
        background: Rectangle {
            radius: 12
            color: Theme.mainBg
            border.color: Theme.borderLight
            border.width: 1
        }

        Column {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 12

            Text {
                text: "传感器状态"
                color: Theme.textMain
                font.pixelSize: 16
                font.bold: true
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.borderLight
            }

            // 传感器列表 - 使用Column配合Item实现对齐
            Column {
                spacing: 8
                width: parent.width

                Row {
                    spacing: 10
                    width: parent.width
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: {
                            var states = core.sensorAlarmStates
                            if (states.length > 0) {
                                return states[0] === 0 ? Theme.accentGreen : (states[0] === 1 ? Theme.accentRed : "#666666")
                            }
                            return "#666666"
                        }
                    }
                    Text { text: "环境温度"; color: Theme.textMain; font.pixelSize: 14; width: 70 }
                    Text { text: core.tempStr + " °C"; color: Theme.textSecondary; font.pixelSize: 14 }
                }

                Row {
                    spacing: 10
                    width: parent.width
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: {
                            var states = core.sensorAlarmStates
                            if (states.length > 1) {
                                return states[1] === 0 ? Theme.accentGreen : (states[1] === 1 ? Theme.accentRed : "#666666")
                            }
                            return "#666666"
                        }
                    }
                    Text { text: "相对湿度"; color: Theme.textMain; font.pixelSize: 14; width: 70 }
                    Text { text: core.humStr + " %"; color: Theme.textSecondary; font.pixelSize: 14 }
                }

                Row {
                    spacing: 10
                    width: parent.width
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: {
                            var states = core.sensorAlarmStates
                            if (states.length > 2) {
                                return states[2] === 0 ? Theme.accentGreen : (states[2] === 1 ? Theme.accentRed : "#666666")
                            }
                            return "#666666"
                        }
                    }
                    Text { text: "光照"; color: Theme.textMain; font.pixelSize: 14; width: 70 }
                    Text { text: core.lightStr + " V"; color: Theme.textSecondary; font.pixelSize: 14 }
                }

                Row {
                    spacing: 10
                    width: parent.width
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: {
                            var states = core.sensorAlarmStates
                            if (states.length > 3) {
                                return states[3] === 0 ? Theme.accentGreen : (states[3] === 1 ? Theme.accentRed : "#666666")
                            }
                            return "#666666"
                        }
                    }
                    Text { text: "MQ135"; color: Theme.textMain; font.pixelSize: 14; width: 70 }
                    Text { text: core.mq135Str + " ppm"; color: Theme.textSecondary; font.pixelSize: 14 }
                }

                Row {
                    spacing: 10
                    width: parent.width
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: {
                            var states = core.sensorAlarmStates
                            if (states.length > 4) {
                                return states[4] === 0 ? Theme.accentGreen : (states[4] === 1 ? Theme.accentRed : "#666666")
                            }
                            return "#666666"
                        }
                    }
                    Text { text: "ZP01"; color: Theme.textMain; font.pixelSize: 14; width: 70 }
                    Text { text: core.zp01Str + " μg/m³"; color: Theme.textSecondary; font.pixelSize: 14 }
                }

                Row {
                    spacing: 10
                    width: parent.width
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: "#666666"
                    }
                    Text { text: "噪音"; color: Theme.textMain; font.pixelSize: 14; width: 70 }
                    Text { text: "已禁用"; color: Theme.textSecondary; font.pixelSize: 14 }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.borderLight
            }

            // 图例
            Row {
                spacing: 20
                anchors.horizontalCenter: parent.horizontalCenter

                Row { spacing: 5
                    Rectangle { width: 10; height: 10; radius: 5; color: Theme.accentGreen }
                    Text { text: "正常"; color: Theme.textSecondary; font.pixelSize: 12 }
                }
                Row { spacing: 5
                    Rectangle { width: 10; height: 10; radius: 5; color: Theme.accentRed }
                    Text { text: "警告"; color: Theme.textSecondary; font.pixelSize: 12 }
                }
                Row { spacing: 5
                    Rectangle { width: 10; height: 10; radius: 5; color: "#666666" }
                    Text { text: "禁用"; color: Theme.textSecondary; font.pixelSize: 12 }
                }
            }
        }
    }

    // --- 底部装饰线 ---
    Rectangle {
        width: parent.width
        height: 1.0
        color: Theme.borderLight
        anchors.bottom: parent.bottom
    }
}
