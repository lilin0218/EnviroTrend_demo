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
    property var dataBuffer: []     // 真实数据（已预处理）
    property var predictList: []    // AI 预测数据（24小时量）
    property double predictBaseTime: 0 // 记录点击预测时的时间点
    property int sampleStep: 5      // 采样步长（与C++保持一致）

    // 状态控制
    property bool isLongTerm: false // 当前是否为 24h 长时图

    // Y 轴范围
    property double limitMinY: 0.0
    property double limitMaxY: 100.0
    property double viewMinY: limitMinY
    property double viewMaxY: limitMaxY

    // 折线抽样控制（控制每次绘制的点数上限）
    property int maxPointsShort: 150
    property int maxPointsLong: 250
    property int maxPredictPointsShort: 150
    property int maxPredictPointsLong: 250

    width: parent.width
    height: 350

    // 监听逻辑
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
                id: gapSeries
                name: "数据缺失"; axisX: axisX; axisY: axisY
                color: "#FF4444"; width: 2; useOpenGL: true
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
                    first.value: root.viewMinY
                    second.value: root.viewMaxY

                    first.onValueChanged: {
                        root.viewMinY = first.value
                    }
                    second.onValueChanged: {
                        root.viewMaxY = second.value
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

    // 短时视图下：每3秒更新一次（降低嵌入式设备CPU负载）
    Timer {
        id: shortViewTimer
        interval: 3000
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

    // 根据实际数据自动计算合适的Y轴范围
    function autoCalcYRange() {
        if (dataBuffer.length === 0) {
            viewMinY = limitMinY
            viewMaxY = limitMaxY
            return
        }

        var dataMin = Infinity
        var dataMax = -Infinity

        for (var i = 0; i < dataBuffer.length; i++) {
            var val = parseFloat(dataBuffer[i])
            if (!isNaN(val)) {
                if (val < dataMin) dataMin = val
                if (val > dataMax) dataMax = val
            }
        }

        if (dataMin === Infinity || dataMax === -Infinity) {
            viewMinY = limitMinY
            viewMaxY = limitMaxY
            return
        }

        var dataRange = dataMax - dataMin
        var padding = dataRange * 0.25 // 上下各留25%的padding，更宽松
        if (padding < 3) padding = 3   // 最小padding为3，更宽松

        var calcMin = dataMin - padding
        var calcMax = dataMax + padding

        // 确保在limit范围内
        if (calcMin < limitMinY) calcMin = limitMinY
        if (calcMax > limitMaxY) calcMax = limitMaxY

        // 确保最小值不超过最大值
        if (calcMin >= calcMax) {
            calcMin = limitMinY
            calcMax = limitMaxY
        }

        viewMinY = calcMin
        viewMaxY = calcMax
    }

    // 在数据或limit变化时重新计算Y轴范围
    onDataBufferChanged: {
        autoCalcYRange()
        updateSeries()
    }

    onLimitMinYChanged: autoCalcYRange()
    onLimitMaxYChanged: autoCalcYRange()

    function updateSeries() {
        if (!series || !gapSeries || !axisX) return
        var nowMs = Date.now()
        var interval = 60000 * root.sampleStep // 采样间隔 = 原始间隔 × 采样步长

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

        // 清空所有 series
        series.clear()
        gapSeries.clear()

        if (totalCount > 0) {
            var lastValidValue = null
            var lastValidTime = null
            var inGap = false
            var gapStartValue = null
            var gapStartTime = null

            for (var i = 0; i < totalCount; i += step) {
                var pTime = nowMs - (totalCount - 1 - i) * interval
                if (pTime < axisX.min.getTime() || pTime > axisX.max.getTime()) {
                    continue
                }

                var val = parseFloat(dataBuffer[i])
                var isNaNVal = isNaN(val)

                if (!isNaNVal) {
                    // 正常数据点
                    if (inGap && lastValidValue !== null) {
                        // 结束一个 gap，从 gap 起点绘制到当前点
                        gapSeries.append(gapStartTime, gapStartValue)
                        gapSeries.append(pTime, val)
                        inGap = false
                    }
                    // 添加到正常 series
                    series.append(pTime, val)
                    lastValidValue = val
                    lastValidTime = pTime
                } else {
                    // NaN 值
                    if (!inGap && lastValidValue !== null) {
                        // 开始一个 gap
                        gapStartValue = lastValidValue
                        gapStartTime = lastValidTime
                        inGap = true
                    }
                    // 不在正常 series 中添加 NaN 值
                }
            }

            // 如果数据以 gap 结尾，不处理（因为没有结束点）
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
