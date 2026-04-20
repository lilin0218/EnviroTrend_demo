import QtQuick 2.11
import "../common" // 假设 Theme.qml 在 common 目录下

Rectangle {
    id: root
    width: 800
    height: 45 // 稍微增加一点高度，视觉比例更好
    color: Theme.mainBg // 使用全局背景色

    // 传感器计数逻辑（现在先写死 1/5）
    property int activeSensors: 1
    property int totalSensors: 5

    // 当前地点
    property string location: "Lab-Room 101"

    // --- 左侧：位置信息 ---
    Row {
        id: leftArea
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // 定位小图标（如果你有图标的话，可以用 Image，这里先用文字符号占位）
        Text {
            text: "定位图标"
            font.pixelSize: Theme.sizeStatusBar
            color: Theme.accentBlue
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            text: root.location
            color: Theme.textSecondary
            font.pixelSize: Theme.sizeStatusBar
            font.family: "PingFang SC" // 或者你安装的字体
            verticalAlignment: Text.AlignVCenter
        }
    }

    // --- 中间：实时时间 ---
    Text {
        id: timeText
        anchors.centerIn: parent
        color: Theme.textMain
        font.pixelSize: Theme.sizeSubTitle // 时间稍微大一点点
        font.bold: true
        font.family: "Monospace" // 等宽字体防止数字跳动

        // 实时更新逻辑
        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                var d = new Date();
                timeText.text = Qt.formatDateTime(d, "hh:mm:ss");
            }
            // 初始化显示
            Component.onCompleted: {
                var d = new Date();
                timeText.text = Qt.formatDateTime(d, "hh:mm:ss");
            }
        }
    }

    // --- 右侧：传感器状态和网络状态 ---
    Row {
        id: rightArea
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 20

        // 网络状态
        Row {
            spacing: 5
            anchors.verticalCenter: parent.verticalCenter

            // 网络状态指示灯
            Rectangle {
                width: 10.0
                height: 10.0
                radius: 5.0
                color: core.isNetworkConnected ? Theme.accentGreen : Theme.accentRed
                anchors.verticalCenter: parent.verticalCenter

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.4; duration: 1500; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 0.4; to: 1.0; duration: 1500; easing.type: Easing.InOutQuad }
                }
            }

            Text {
                text: core.isNetworkConnected ? "Online" : "Offline"
                color: core.isNetworkConnected ? Theme.accentGreen : Theme.accentRed
                font.pixelSize: Theme.sizeStatusBar
                font.bold: true
                verticalAlignment: Text.AlignVCenter
            }
        }

        // 传感器状态
        Row {
            spacing: 5
            anchors.verticalCenter: parent.verticalCenter

            // 状态指示灯（呼吸灯效果）
            Rectangle {
                width: 10.0
                height: 10.0
                radius: 5.0
                color: Theme.accentGreen
                anchors.verticalCenter: parent.verticalCenter

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.4; duration: 1500; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 0.4; to: 1.0; duration: 1500; easing.type: Easing.InOutQuad }
                }
            }

            Text {
                text: "Sensors: " + root.activeSensors + " / " + root.totalSensors
                color: Theme.accentBlue
                font.pixelSize: Theme.sizeStatusBar
                font.bold: true
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // --- 底部装饰线 (特斯拉风格的极细线) ---
    Rectangle {
        width: parent.width
        height: 1.0
        color: Theme.borderLight
        anchors.bottom: parent.bottom
    }
}
