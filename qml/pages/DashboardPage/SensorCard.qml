import QtQuick 2.11
import QtQuick.Controls 2.4
import QtQuick.Dialogs 1.2
import "qrc:/qml/common"

Rectangle {
    id: card
    radius: Theme.borderRadius

    // --- 动态样式绑定 (核心逻辑) ---
    property bool active: core.getSensorActive(sensorId)
    property int interval: core.getSensorInterval(sensorId)

    color: active ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.03)
    border.color: active ? Theme.accentBlue : "#444444"
    border.width: active ? 1.5 : 1.0

    property string label: ""
    property string value: ""
    property string unit: ""
    property string iconSource_checked: "qrc:/res/placeholder.png"
    property string iconSource_unchecked: "qrc:/res/placeholder.png"
    property int sensorId: -1
    property string sensorName: ""

    // 交互：双击或右键弹出菜单
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onDoubleClicked: sensorMenu.open()
        onClicked: if (mouse.button === Qt.RightButton) sensorMenu.open()

        // 悬停效果
        hoverEnabled: true
        onEntered: {
            card.border.color = active ? Theme.accentBlue : "#666666"
            card.scale = 1.02
        }
        onExited: {
            card.border.color = active ? Theme.accentBlue : "#444444"
            card.scale = 1.0
        }
    }

    // 动画
    Behavior on border.color {
        ColorAnimation { duration: 200 }
    }
    Behavior on scale {
        NumberAnimation { duration: 200 }
    }

    // --- 内容区域 ---
    Row {
        anchors.fill: parent
        anchors.margins: parent.width * 0.08
        spacing: parent.width * 0.05
        opacity: card.active ? 1.0 : 0.4 // 未启用时整体变暗

        // 图标区域
        Item {
            width: parent.height; height: width
            anchors.verticalCenter: parent.verticalCenter

            // 未选中/禁用 状态的图标
            Image {
                anchors.fill: parent
                source: iconSource_unchecked
                opacity: card.active ? 0.0 : 1.0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            // 选中/启用 状态的图标
            Image {
                anchors.fill: parent
                source: iconSource_checked
                opacity: card.active ? 1.0 : 0.0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: card.label;
                color: card.active ? Theme.textSecondary : "#666666"
                font.pixelSize: card.height * 0.15
            }
            Text {
                text: card.active ? (card.value + " " + card.unit) : "已禁用"
                color: card.active ? Theme.textMain : "#888888"
                font.bold: true; font.pixelSize: card.height * 0.22
            }
        }
    }

    // --- 模态配置菜单 ---
    Dialog {
        id: sensorMenu
        title: "传感器设置"
        width: parent.width * 0.7
        height: parent.height * 0.55
        modality: Qt.ApplicationModal
        standardButtons: Dialog.Ok

        contentItem: Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 20

            Text {
                width: parent.width
                text: "正在设置 " + sensorName + " 传感器"
                color: Theme.accentBlue
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: parent.height * 0.08
            }

            // 启用开关：直接修改 core
            Row {
                width: parent.width
                height: 40
                spacing: 20
                Text {
                    text: "启用状态："
                    color: Theme.textMain
                    anchors.verticalCenter: parent.verticalCenter
                }
                Switch {
                    checked: active // 绑定 Core
                    onCheckedChanged: {
                        core.setSensorActive(card.sensorId, checked)
                    }
                }
            }

            // 刷新频率：直接修改 core
            Row {
                width: parent.width
                height: 40
                spacing: 20
                Text {
                    text: "刷新间隔："
                    color: Theme.textMain
                    anchors.verticalCenter: parent.verticalCenter
                }
                SpinBox {
                    from: 1
                    to: 5
                    value: interval // 绑定 Core
                    onValueModified: {
                        core.setSensorInterval(card.sensorId, value)
                    }
                }
                Text {
                    text: "秒"
                    color: Theme.textSecondary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                width: parent.width
                text: "点击确定按钮保存设置"
                color: Theme.textSecondary
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // 监听 core 的信号
    Connections {
        target: core
        function onSensorSig(id) {
            if (id !== card.sensorId) return
            card.active = core.getSensorActive(card.sensorId)
            card.interval = core.getSensorInterval(card.sensorId)
        }
    }
}

