import QtQuick 2.11
import QtQuick.Controls 2.4
import QtCharts 2.0
import QtQml 2.11
import "../../common"
import "../../components"

Item {
    id: root

    // --- 接口属性 ---
    property string title: "传感器数据"
    property color lineColor: "#00CCFF"
    property color aiLineColor: "#FF9900"

    // 数据源
    property var dataBuffer: []     // 真实数据
    property var predictList: []    // AI 预测数据（24小时量）
    property double predictBaseTime: 0 // 记录点击预测时的时间点

    // 状态控制
    property bool isLongTerm: false // 当前是否为 24h 长时图

    // Y 轴范围
    property double limitMinY: 0.0
    property double limitMaxY: 100.0
    property double viewMinY: 0.0
    property double viewMaxY: 100.0

    // 折线抽样控制（控制每次绘制的点数上限）
    property int maxPointsShort: 150
    property int maxPointsLong: 250
    property int maxPredictPointsShort: 150
    property int maxPredictPointsLong: 250

    width: parent.width
    height: 350

    // 监听逻辑
    onDataBufferChanged: updateSeries()
    onPredictListChanged: {
        // 捕获生成预测瞬间的时间基准（使用当前系统时间）
        predictBaseTime = Date.now()
        updateSeries()
    }
    onViewMinYChanged: updateSeries()
    onViewMaxYChanged: updateSeries()

    // --- 界面布局 ---
    Row {
        anchors.fill: parent
        anchors.margins: 5
        spacing: 20

        // 1. 左侧：图表主区域
        ChartView {
            id: chart
            width: parent.width - 150
            height: parent.height
            antialiasing: false
            backgroundColor: "transparent"
            legend.visible: true
            legend.alignment: Qt.AlignBottom
            legend.labelColor: "white"
            title: root.isLongTerm ? root.title + " (24H长时)" : root.title + " (短时实时)"
            titleColor: "white"

            DateTimeAxis {
                id: axisX
                tickCount: root.isLongTerm ? 7 : 5
                labelsColor: "#AAAAAA"
                gridLineColor: "#333333"
                format: root.isLongTerm ? "HH:mm" : "HH:mm:ss"
            }

            ValueAxis {
                id: axisY
                min: root.viewMinY
                max: root.viewMaxY
                labelsColor: "#AAAAAA"
                gridLineColor: "#333333"
                labelFormat: "%.1f"
                tickCount: 5
            }

            LineSeries {
                id: series
                name: "实际观测"; axisX: axisX; axisY: axisY
                color: root.lineColor; width: 2; useOpenGL: true
            }

            LineSeries {
                id: predictSeries
                name: "LSTM 预测"; axisX: axisX; axisY: axisY
                color: root.aiLineColor; width: 2; useOpenGL: true
            }

            // 最近预测时间提示
            Text {
                id: lastPredictLabel
                anchors.horizontalCenter: chart.horizontalCenter
                anchors.bottom: chart.bottom
                anchors.bottomMargin: 4
                color: "#CCCCCC"
                font.pixelSize: 10
                text: predictList.length > 0
                      ? "最近预测起点: " + Qt.formatDateTime(new Date(predictBaseTime), "MM-dd HH:mm")
                      : ""
            }
        }

        // 2. 右侧：控制区
        Column {
            width: 140
            spacing: 15

            // 视图切换按钮
            CustomButton {
                width: 130; height: 35
                text: root.isLongTerm ? "短时视图" : "24h视图"
                onClicked: {
                    root.isLongTerm = !root.isLongTerm
                    updateSeries()
                }
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Y轴范围控制 - 使用CustomRangeSlider
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5
                height: parent.height * 0.6

                CustomRangeSlider {
                    id: yRangeSlider
                    width: 60
                    height: parent.height
                    orientation: Qt.Vertical
                    from: root.limitMinY
                    to: root.limitMaxY
                    labelPosition: "Right"
                    
                    // 使用onPressedChanged来避免绑定循环
                    first.onPressedChanged: {
                        if (!first.pressed) {
                            root.viewMinY = first.value
                        }
                    }
                    second.onPressedChanged: {
                        if (!second.pressed) {
                            root.viewMaxY = second.value
                        }
                    }
                    
                    // 初始化值
                    Component.onCompleted: {
                        first.value = root.viewMinY
                        second.value = root.viewMaxY
                    }
                }
            }

            // AI预测手动触发
            CustomButton {
                id: predictBtn
                text: core.isAiBusy ? "..." : "AI预测"
                enabled: !core.isAiBusy
                width: 130; height: 35
                onClicked: core.runPrediction()
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // 短时视图下：每秒让当前时间居中，形成连续滑动效果
    Timer {
        id: shortViewTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (!root.isLongTerm) {
                updateSeries()
                checkDayReset()
            }
        }
    }

    // --- 核心逻辑函数 ---

    function updateSeries() {
        if (!series || !axisX) return
        var nowMs = Date.now() // 使用当前系统时间
        var interval = 60000 // 默认1分钟

        // 1. 设置 X 轴范围
        if (root.isLongTerm) {
            // 长时图：固定 0:00 - 24:00
            var today = new Date(nowMs)
            today.setHours(0,0,0,0)
            axisX.min = today
            var tomorrow = new Date(today.getTime() + 24 * 3600 * 1000)
            axisX.max = tomorrow
        } else {
            // 短时图：过去1h + 未来1h，当前时间居中
            axisX.min = new Date(nowMs - 3600 * 1000)
            axisX.max = new Date(nowMs + 3600 * 1000)
        }

        // 2. 绘制逻辑
        // 根据当前数据量和视图模式动态控制点的采样步长，避免在嵌入式上一次性绘制过多点
        var totalCount = dataBuffer.length
        var maxPoints = root.isLongTerm ? root.maxPointsLong : root.maxPointsShort
        var step = 1
        if (totalCount > maxPoints && maxPoints > 0) {
            step = Math.floor(totalCount / maxPoints)
            if (step < 1) step = 1
        }

        // 绘制真实线
        series.clear()
        if (totalCount > 0) {
            for (var i = 0; i < totalCount; i += step) {
                // 时间戳计算：假设 buffer 最后一点是当前时间
                var pTime = nowMs - (totalCount - 1 - i) * interval
                if (pTime >= axisX.min.getTime() && pTime <= axisX.max.getTime()) {
                    series.append(pTime, dataBuffer[i])
                }
            }
        }

        // 绘制预测线 (24H 预测量)
        predictSeries.clear()
        var predictCount = predictList.length
        if (predictCount > 0 && predictBaseTime > 0) {
            var axisMinMs = axisX.min.getTime()
            var axisMaxMs = axisX.max.getTime()

            // 计算当前 X 轴窗口内的预测点索引范围 [jStart, jEnd]
            var firstIdx = Math.ceil((axisMinMs - predictBaseTime) / interval)
            var lastIdx = Math.floor((axisMaxMs - predictBaseTime) / interval)
            if (firstIdx < 0) firstIdx = 0
            if (lastIdx >= predictCount) lastIdx = predictCount - 1

            if (lastIdx >= firstIdx) {
                var inRangeCount = lastIdx - firstIdx + 1
                var maxPredict = root.isLongTerm ? root.maxPredictPointsLong : root.maxPredictPointsShort
                var pStep = 1
                if (inRangeCount > maxPredict && maxPredict > 0) {
                    pStep = Math.floor(inRangeCount / maxPredict)
                    if (pStep < 1) pStep = 1
                }

                for (var j = firstIdx; j <= lastIdx; j += pStep) {
                    var pAiTime = predictBaseTime + (j * interval)
                    predictSeries.append(pAiTime, parseFloat(predictList[j]))
                }
            }
        }
    }

    // 检查是否到达午夜并清空长时数据
    function checkDayReset() {
        var d = new Date()
        // 如果是 00:00:00 附近（根据你的采样频率调整判定范围）
        if (d.getHours() === 0 && d.getMinutes() === 0 && d.getSeconds() < 2) {
            console.log("[SYSTEM] Midnight reached. Clearing long-term buffer.")
            // 这里建议调用 core 接口清空历史数据，QML 随之更新
            core.clearHistoryBuffer()
        }
    }
}
