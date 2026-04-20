import QtQuick 2.11
import "../../common" // 引入 Theme.qml

Rectangle {
    id: root
    width: 90 // 稍微加宽一点以适配图标加文字的布局
    color: "transparent"

    // --- 接口信号 ---
    signal itemSelected(int index)

    // 当前选中的索引
    property int currentIndex: 0

    // 使用你提供的资源路径规划模型
    ListModel {
        id: navModel
        ListElement {
            name: "温度";
            tag: "temp";
        }
        ListElement {
            name: "湿度";
            tag: "hum";
        }
        ListElement {
            name: "光照";
            tag: "light";
        }
        ListElement {
            name: "噪音";
            tag: "noise";
        }
        ListElement {
            name: "颗粒物";
            tag: "particle";
        }
        ListElement {
            name: "AQI";
            tag: "aqi";
        }
    }

    Column {
        anchors.fill: parent

        Repeater {
            model: navModel
            delegate: Item {
                id: btn
                width: root.width
                height: root.height / 6 // 增加高度以容纳图标和文字

                // 按钮背景状态
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    color: root.currentIndex === index ? "#2A2A2A" : "transparent"
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    // 动态切换图标逻辑
                    Image {
                        width: btn.width / 4
                        height: width
                        anchors.horizontalCenter: parent.horizontalCenter
                        source: {
                            // 拼接路径：比如 "qrc:/res/sensor/temp_checked.png"
                            let status = (root.currentIndex === index) ? "checked" : "unchecked";
                            return "qrc:/res/sensor/" + tag + "_" + status + ".png";
                        }
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        text: name
                        color: root.currentIndex === index ? "white" : "#666666"
                        font.pixelSize: btn.width / 6
                        font.bold: root.currentIndex === index
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.currentIndex = index;
                        root.itemSelected(index);
                    }
                }
            }
        }
    }

    // 右侧精致边界线
    Rectangle {
        width: 2
        height: parent.height
        anchors.right: parent.right
        color: "#333333"
    }
}
