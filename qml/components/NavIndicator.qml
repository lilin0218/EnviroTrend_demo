import QtQuick 2.11
import "../common"

Rectangle {
    id: flowIndicator

    // --- 外部接口：由父组件传入 ---
    property int currentIndex: 0
    property double containerWidth: 800.0
    property double containerHeight: 85.0
    property int itemCount: 5

    // --- 内部比例计算 ---
    readonly property double unitWidth: containerWidth / itemCount
    readonly property double baseWidth: unitWidth * 0.5
    readonly property double baseHeight: containerHeight * 0.1

    // --- 基础样式 ---
    width: baseWidth
    height: baseHeight
    radius: 4.0
    color: Theme.accentBlue
    anchors.bottom: parent.bottom // 依然可以保留在底部

    // --- 坐标逻辑 ---
    // (index + 0.5) * unitWidth 是中心点，减去 width/2 得到左侧起点
    x: (unitWidth * (currentIndex + 0.5)) - (width / 2.0)

    property bool isMoving: false

    // 监控索引变化，开启移动状态
    onCurrentIndexChanged: isMoving = true

    states: [
        State {
            name: "MOVING"
            when: flowIndicator.isMoving
            PropertyChanges {
                target: flowIndicator
                color: Theme.accentPurple
                height: baseHeight * 0.5
                opacity: 0.5
            }
        },
        State {
            name: "IDLE"
            when: !flowIndicator.isMoving
            PropertyChanges {
                target: flowIndicator
                color: Theme.accentBlue
                height: baseHeight
                opacity: 1.0
            }
        }
    ]

    // --- 动画定义 ---
    readonly property int dura: 500
    Behavior on height { NumberAnimation { duration: dura; easing.type: Easing.OutQuint } }
    Behavior on color { ColorAnimation { duration: dura } }
    Behavior on opacity { NumberAnimation { duration: dura } }
    Behavior on x {
        NumberAnimation {
            duration: flowIndicator.dura // 严格遵守你的时长设置

            // Easing.OutBack 是模拟弹簧的最佳曲线
            easing.type: Easing.OutBack

            // 这里的 amplitude 相当于弹簧的幅度
            // 1.0 是标准回弹，1.5 是大幅度回弹
            easing.amplitude: 1.2

            onRunningChanged: {
                if (!running) flowIndicator.isMoving = false
            }
        }
    }
}
