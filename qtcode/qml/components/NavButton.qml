import QtQuick 2.11
import "../common"

Item {
    id: navBtn
    width: parent.width / 5
    height: parent.height

    // 基础名称，例如 "navDashboard"
    property string iconBaseName: ""
    property string labelText: ""
    property bool isActive: false

    signal clicked()

    // 整体缩放动画保持不变
    scale: isActive ? 1.2 : 1.0
    Behavior on scale {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutBack }
    }

    Column {
        anchors.centerIn: parent
        spacing: 6

        Item {
            width: 32.0
            height: 32.0
            anchors.horizontalCenter: parent.horizontalCenter

            // 1. 普通状态图片 (未选中)
            Image {
                id: normalImg
                source: "qrc:/res/navigationBar/" + navBtn.iconBaseName + "_unchecked.png"
                anchors.fill: parent
                opacity: navBtn.isActive ? 0.0 : 1.0
                smooth: true
                Behavior on opacity { NumberAnimation { duration: Theme.animDuration } }
            }

            // 2. 激活状态图片 (已选中)
            Image {
                id: activeImg
                source: "qrc:/res/navigationBar/" + navBtn.iconBaseName + "_checked.png"
                anchors.fill: parent
                opacity: navBtn.isActive ? 1.0 : 0.0
                smooth: true
                Behavior on opacity { NumberAnimation { duration: Theme.animDuration } }
            }
        }

        Text {
            text: navBtn.labelText
            color: navBtn.isActive ? Theme.accentBlue : Theme.textSecondary
            font.pixelSize: Theme.sizeNavLabel
            anchors.horizontalCenter: parent.horizontalCenter
            Behavior on color { ColorAnimation { duration: Theme.animDuration } }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: navBtn.clicked()
    }
}
