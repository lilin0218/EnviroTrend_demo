import QtQuick 2.11
import QtQuick.Controls 1.4
import QtQuick.Controls.Styles 1.4

Slider {
    id: control

    // 希望当前数值的标签出现在滑块的哪个方向
    property string labelPosition: "Top" // 可选值: "Top", "Bottom", "Left", "Right"

    // 基础尺寸设置
    implicitWidth: orientation === Qt.Horizontal ? 200 : 40
    implicitHeight: orientation === Qt.Horizontal ? 40 : 200

    style: SliderStyle {
        groove: Rectangle {
            implicitWidth: control.orientation === Qt.Horizontal ? 200 : 4
            implicitHeight: control.orientation === Qt.Horizontal ? 4 : 200
            width: control.orientation === Qt.Horizontal ? control.availableWidth : implicitWidth
            height: control.orientation === Qt.Horizontal ? implicitHeight : control.availableHeight
            color: "#bdbebf"

            // 1. 起点数值 (左/下)
            Text {
                text: control.minimumValue.toFixed(0)
                font.pixelSize: 10
                color: "#888"
                anchors.right: control.orientation === Qt.Horizontal ? parent.left : undefined
                anchors.top: control.orientation === Qt.Horizontal ? parent.bottom : parent.bottom
                anchors.rightMargin: control.orientation === Qt.Horizontal ? 5 : 0
                anchors.horizontalCenter: control.orientation === Qt.Horizontal ? undefined : parent.horizontalCenter
            }

            // 2. 终点数值 (右/上)
            Text {
                text: control.maximumValue.toFixed(0)
                font.pixelSize: 10
                color: "#888"
                anchors.left: control.orientation === Qt.Horizontal ? parent.right : undefined
                anchors.bottom: control.orientation === Qt.Horizontal ? parent.bottom : parent.top
                anchors.leftMargin: control.orientation === Qt.Horizontal ? 5 : 0
                anchors.horizontalCenter: control.orientation === Qt.Horizontal ? undefined : parent.horizontalCenter
            }

            // 3. 已填充进度条部分 (绿色部分 z+1)
            Rectangle {
                z: parent.z + 1
                width: control.orientation === Qt.Horizontal ? (control.value - control.minimumValue) / (control.maximumValue - control.minimumValue) * parent.width : parent.width
                height: control.orientation === Qt.Horizontal ? parent.height : (control.value - control.minimumValue) / (control.maximumValue - control.minimumValue) * parent.height

                // 修正：水平从左往右，垂直从下往上
                anchors.left: parent.left
                anchors.bottom: parent.bottom

                color: "#21be2b"
            }
        }

        handle: Rectangle {
            id: handleVisual
            width: 26
            height: 13

            // 4. 视觉效果：悬空放大，按住变色
            color: control.down ? "grey" : (control.hovered ? "#ffffff" : "#f6f6f6")
            scale: control.down ? 0.9 : (control.hovered ? 1.15 : 1.0)
            border.color: control.hovered ? "#21be2b" : "#bdbebf"
            border.width: 3

            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutBack
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }

            Rectangle {
                color: "#333"
                visible: control.hovered || control.down
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
                    text: control.value.toFixed(1) // 保持 double 精度习惯
                    color: "white"
                    font.pixelSize: 11
                }
            }
        }
    }
}
