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
    property var timestampBuffer: [] // 数据点时间戳（毫秒）
    property double predictBaseTime: 0 // 记录点击预测时的时间点
    property int sampleStep: 5      // 采样步长（与C++保持一致）

    // Y 轴范围
    property double limitMinY: 0.0
    property double limitMaxY: 100.0
    property double viewMinY: limitMinY
    property double viewMaxY: limitMaxY

    // 折线抽样控制（控制每次绘制的点数上限）
    property int maxPointsLong: 250
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
            title: root.title + " (24H长时)"
            titleColor: "white"

            DateTimeAxis {
                id: axisX
                tickCount: 7
                labelsColor: "#AAAAAA"
                gridLineColor: "#333333"
                format: "HH:mm"
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
            id: controlColumn
            width: 140
            height: parent.height
            spacing: 15

            // Y轴范围控制 - 使用CustomRangeSlider
            Item {
                width: 140
                height: controlColumn.height - predictBtn.height - controlColumn.spacing

                CustomRangeSlider {
                    id: yRangeSlider
                    width: 60
                    height: parent.height
                    anchors.horizontalCenter: parent.horizontalCenter
                    orientation: Qt.Vertical
                    from: root.limitMinY
                    to: root.limitMaxY
                    labelPosition: "Right"
                    first.value: root.viewMinY
                    second.value: root.viewMaxY

                    onFirstValueChanged: {
                        if (Math.abs(yRangeSlider.first.value - root.viewMinY) > 0.01) {
                            root.viewMinY = yRangeSlider.first.value
                        }
                    }
                    onSecondValueChanged: {
                        if (Math.abs(yRangeSlider.second.value - root.viewMaxY) > 0.01) {
                            root.viewMaxY = yRangeSlider.second.value
                        }
                    }
                }
            }

            // AI预测手动触发
            CustomButton {
                id: predictBtn
                text: core.isAiBusy ? "预测中，请稍候" : "LSTM预测"
                enabled: !core.isAiBusy
                width: 130; height: 35
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: core.runPrediction()
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

        // 设置 X 轴范围 - 长时图：固定 0:00 - 24:00
        var today = new Date(nowMs)
        today.setHours(0,0,0,0)
        axisX.min = today
        var tomorrow = new Date(today.getTime() + 24 * 3600 * 1000)
        axisX.max = tomorrow

        var axisMinMs = axisX.min.getTime()
        var axisMaxMs = axisX.max.getTime()

        // 清空所有 series
        series.clear()
        gapSeries.clear()

        // 根据当前数据量动态控制点的采样步长，避免在嵌入式上一次性绘制过多点
        var totalCount = dataBuffer.length
        var maxPoints = root.maxPointsLong
        var step = 1
        if (totalCount > maxPoints && maxPoints > 0) {
            step = Math.floor(totalCount / maxPoints)
            if (step < 1) step = 1
        }

        if (totalCount > 0) {
            var lastValidTime = null
            var lastValidValue = null
            var inGap = false
            var gapStartValue = null
            var gapStartTime = null

            // 遍历所有数据点，根据真实时间戳绘制
            for (var i = 0; i < totalCount; i += step) {
                var val = parseFloat(dataBuffer[i])
                var isNaNVal = isNaN(val)

                // 获取真实时间戳（如果有）
                var pTime = null
                if (timestampBuffer && i < timestampBuffer.length) {
                    var ts = parseFloat(timestampBuffer[i])
                    if (!isNaN(ts) && ts > 0) {
                        pTime = ts
                    }
                }

                // 如果时间戳无效，使用计算时间作为后备
                // 计算时间：从当前时间往前推，假设数据是连续的
                if (pTime === null) {
                    pTime = nowMs - (totalCount - 1 - i) * interval
                }

                // 检查是否在X轴范围内
                if (pTime < axisMinMs || pTime > axisMaxMs) {
                    continue
                }

                if (!isNaNVal) {
                    // 正常数据点
                    if (inGap && lastValidValue !== null && lastValidTime !== null) {
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
                    // NaN 值，标记为gap
                    if (!inGap && lastValidValue !== null && lastValidTime !== null) {
                        // 开始一个 gap
                        gapStartValue = lastValidValue
                        gapStartTime = lastValidTime
                        inGap = true
                    }
                }
            }

            // 如果数据以 gap 结尾，绘制到X轴末端
            if (inGap && gapStartValue !== null && gapStartTime !== null) {
                gapSeries.append(gapStartTime, gapStartValue)
                gapSeries.append(axisMaxMs, gapStartValue)
            }
        }

        // 绘制预测线 (24H 预测量)
        predictSeries.clear()
        var predictCount = predictList.length
        if (predictCount > 0 && predictBaseTime > 0) {
            // 计算当前 X 轴窗口内的预测点索引范围 [jStart, jEnd]
            var firstIdx = Math.ceil((axisMinMs - predictBaseTime) / interval)
            var lastIdx = Math.floor((axisMaxMs - predictBaseTime) / interval)
            if (firstIdx < 0) firstIdx = 0
            if (lastIdx >= predictCount) lastIdx = predictCount - 1

            if (lastIdx >= firstIdx) {
                var inRangeCount = lastIdx - firstIdx + 1
                var maxPredict = root.maxPredictPointsLong
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
}
