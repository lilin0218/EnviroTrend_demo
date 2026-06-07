import QtQuick 2.11
import QtQuick.Controls 2.4

RangeSlider {
    id: control

    // 希望当前数值的标签出现在滑块的哪个方向
    property string labelPosition: "Top" // 可选值: "Top", "Bottom", "Left", "Right"

    implicitWidth: horizontal ? 200 : 40
    implicitHeight: horizontal ? 40 : 200

    // 背景轨道
    background: Rectangle {
        id: bgRect
        x: control.leftPadding + (control.horizontal ? 0 : (control.availableWidth - width) / 2)
        y: control.topPadding + (control.horizontal ? (control.availableHeight - height) / 2 : 0)
        implicitWidth: control.horizontal ? 200 : 4
        implicitHeight: control.horizontal ? 4 : 200
        width: control.horizontal ? control.availableWidth : implicitWidth
        height: control.horizontal ? implicitHeight : control.availableHeight
        color: "#bdbebf"

        // 1. 起点/终点数值
        Text {
            text: control.from.toFixed(0)
            font.pixelSize: 10; color: "#888"
            anchors.horizontalCenter: control.horizontal ? undefined : parent.horizontalCenter
            anchors.right: control.horizontal ? parent.left : undefined
            anchors.top: control.horizontal ? parent.bottom : parent.bottom
            anchors.rightMargin: 5
        }
        Text {
            text: control.to.toFixed(0)
            font.pixelSize: 10; color: "#888"
            anchors.horizontalCenter: control.horizontal ? undefined : parent.horizontalCenter
            anchors.left: control.horizontal ? parent.right : undefined
            anchors.bottom: control.horizontal ? parent.bottom : parent.top
            anchors.leftMargin: 5
        }

        // 2. 选中区域
        Rectangle {
            // 水平：x由first决定；垂直：y由second决定（数值大者y小）
            x: control.horizontal ? control.first.visualPosition * parent.width : 0
            y: control.horizontal ? 0 : control.second.visualPosition * parent.height

            width: control.horizontal ? (control.second.visualPosition - control.first.visualPosition) * parent.width : parent.width
            height: control.horizontal ? parent.height : (control.first.visualPosition - control.second.visualPosition) * parent.height

            color: "#21be2b"
        }
    }

    // 3. 第一个滑块 (First Handle)
    first.handle: Rectangle {
        id: firstHandle
        x: control.horizontal ? control.leftPadding + control.first.visualPosition * (control.availableWidth - width) : control.leftPadding + (control.availableWidth - width) / 2
        y: control.horizontal ? control.topPadding + (control.availableHeight - height) / 2 : control.topPadding + control.first.visualPosition * (control.availableHeight - height)
        implicitWidth: 26; implicitHeight: 26 / 2;
        color: control.first.pressed ? "#e0e0e0" : (control.first.hovered ? "#ffffff" : "#f6f6f6")
        border.width: 3
        border.color: control.first.hovered ? "#21be2b" : "#bdbebf"
        scale: control.first.pressed ? 0.9 : (control.first.hovered ? 1.15 : 1.0)
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

        Rectangle {
            color: "#333"
            visible: control.first.hovered || control.first.pressed
            z: 10 // 确保标签在最上层

            // 动态逻辑控制位置
            anchors.bottom: labelPosition === "Top" ? parent.top : undefined
            anchors.top: labelPosition === "Bottom" ? parent.bottom : undefined
            anchors.right: labelPosition === "Left" ? parent.left : undefined
            anchors.left: labelPosition === "Right" ? parent.right : undefined

            // 边距控制
            anchors.bottomMargin: labelPosition === "Top" ? 10 : 0
            anchors.topMargin: labelPosition === "Bottom" ? 10 : 0
            anchors.rightMargin: labelPosition === "Left" ? 10 : 0
            anchors.leftMargin: labelPosition === "Right" ? 10 : 0

            // 居中对齐逻辑
            // 如果是上下位置，则水平居中；如果是左右位置，则垂直居中
            anchors.horizontalCenter: (labelPosition === "Top" || labelPosition
                                       === "Bottom") ? parent.horizontalCenter : undefined
            anchors.verticalCenter: (labelPosition === "Left" || labelPosition
                                     === "Right") ? parent.verticalCenter : undefined

            Text {
                anchors.centerIn: parent
                text: control.first.value.toFixed(1) // 保持 double 精度习惯
                color: "white"
                font.pixelSize: 11
            }
        }
    }

    // 4. 第二个滑块 (Second Handle)
    second.handle: Rectangle {
        id: secondHandle
        x: control.horizontal ? control.leftPadding + control.second.visualPosition * (control.availableWidth - width) : control.leftPadding + (control.availableWidth - width) / 2
        y: control.horizontal ? control.topPadding + (control.availableHeight - height) / 2 : control.topPadding + control.second.visualPosition * (control.availableHeight - height)
        implicitWidth: 26; implicitHeight: 26 / 2;
        color: control.second.pressed ? "#e0e0e0" : (control.second.hovered ? "#ffffff" : "#f6f6f6")
        border.width: 3
        border.color: control.second.hovered ? "#21be2b" : "#bdbebf"
        scale: control.second.pressed ? 0.9 : (control.second.hovered ? 1.15 : 1.0)
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

        Rectangle {
            color: "#333"
            visible: control.second.hovered || control.second.pressed
            z: 10 // 确保标签在最上层

            // 动态逻辑控制位置
            anchors.bottom: labelPosition === "Top" ? parent.top : undefined
            anchors.top: labelPosition === "Bottom" ? parent.bottom : undefined
            anchors.right: labelPosition === "Left" ? parent.left : undefined
            anchors.left: labelPosition === "Right" ? parent.right : undefined

            // 边距控制
            anchors.bottomMargin: labelPosition === "Top" ? 10 : 0
            anchors.topMargin: labelPosition === "Bottom" ? 10 : 0
            anchors.rightMargin: labelPosition === "Left" ? 10 : 0
            anchors.leftMargin: labelPosition === "Right" ? 10 : 0

            // 居中对齐逻辑
            // 如果是上下位置，则水平居中；如果是左右位置，则垂直居中
            anchors.horizontalCenter: (labelPosition === "Top" || labelPosition
                                       === "Bottom") ? parent.horizontalCenter : undefined
            anchors.verticalCenter: (labelPosition === "Left" || labelPosition
                                     === "Right") ? parent.verticalCenter : undefined

            Text {
                anchors.centerIn: parent
                text: control.second.value.toFixed(1) // 修复：显示第二个滑块的值
                color: "white"
                font.pixelSize: 11
            }
        }
    }

    // 连接内部信号
    Connections {
        target: control.first
        onValueChanged: {
            control.firstValueChanged()
        }
    }

    Connections {
        target: control.second
        onValueChanged: {
            control.secondValueChanged()
        }
    }

    // 定义信号
    signal firstValueChanged()
    signal secondValueChanged()
}
