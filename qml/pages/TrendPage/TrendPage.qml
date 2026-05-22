import QtQuick 2.11
import QtQuick.Layouts 1.0
import "../../common"

Rectangle {
    id: root
    color: "transparent"

    // 当前选中的传感器索引
    property int currentIndex: 0

    // 当前传感器配置
    property string currentTitle: "温度趋势 (°C)"
    property double currentLimitMinY: -10.0
    property double currentLimitMaxY: 40.0
    property var currentDataBuffer: core.sampledTempBuffer
    property var currentPredictList: core.predictedTempList

    // 传感器配置数组 - 使用ListModel替代var声明
    ListModel {
        id: sensorConfigs
        ListElement { title: "温度趋势 (°C)"; limitMinY: -10.0; limitMaxY: 40.0; bufferType: "temp" }
        ListElement { title: "湿度趋势 (%)"; limitMinY: 0.0; limitMaxY: 100.0; bufferType: "hum" }
        ListElement { title: "光照趋势 (V)"; limitMinY: 0.0; limitMaxY: 5.0; bufferType: "light" }
        ListElement { title: "MQ135 (气体颗粒物)趋势 (ppm)"; limitMinY: 0.0; limitMaxY: 500.0; bufferType: "mq135" }
        ListElement { title: "ZP01 (空气质量)趋势 (μg/m³)"; limitMinY: 0.0; limitMaxY: 300.0; bufferType: "zp01" }
        ListElement { title: "噪音趋势 (db)"; limitMinY: 0.0; limitMaxY: 120.0; bufferType: "noise" }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // 1. 左侧：导航锚点栏
        SideAnchorBar {
            id: sideBar
            Layout.fillHeight: true
            Layout.preferredWidth: 90
            currentIndex: root.currentIndex

            onItemSelected: {
                root.currentIndex = index;
            }
        }

        // 2. 右侧：单一图表展示区
        Item {
            id: chartContainer
            Layout.fillWidth: true
            Layout.fillHeight: true

            // 噪音传感器页面
            Rectangle {
                id: noisePage
                anchors.fill: parent
                color: "transparent"
                visible: currentIndex === 5

                Text {
                    text: "噪音传感器未启用"
                    color: "#666666"
                    font.pixelSize: 24
                    anchors.centerIn: parent
                }
            }

            // 单一图表组件 - 只创建一个，根据选择动态切换数据源
            TrendChart {
                id: mainChart
                anchors.fill: parent
                visible: currentIndex !== 5

                title: root.currentTitle
                limitMinY: root.currentLimitMinY
                limitMaxY: root.currentLimitMaxY
                dataBuffer: root.currentDataBuffer
                predictList: root.currentPredictList
                sampleStep: core.sampleStep
            }
        }
    }

    // 当前选中索引变化时，更新图表配置
    onCurrentIndexChanged: {
        sideBar.currentIndex = currentIndex;
        if (currentIndex >= 0 && currentIndex < sensorConfigs.count) {
            var config = sensorConfigs.get(currentIndex);
            root.currentTitle = config.title;
            root.currentLimitMinY = config.limitMinY;
            root.currentLimitMaxY = config.limitMaxY;
            
            // 根据 bufferType 设置对应的数据源
            switch(config.bufferType) {
                case "temp":
                    root.currentDataBuffer = core.sampledTempBuffer;
                    root.currentPredictList = core.predictedTempList;
                    break;
                case "hum":
                    root.currentDataBuffer = core.sampledHumBuffer;
                    root.currentPredictList = core.predictedHumList;
                    break;
                case "light":
                    root.currentDataBuffer = core.sampledLightBuffer;
                    root.currentPredictList = core.predictedLightList;
                    break;
                case "mq135":
                    root.currentDataBuffer = core.sampledMq135Buffer;
                    root.currentPredictList = core.predictedMq135List;
                    break;
                case "zp01":
                    root.currentDataBuffer = core.sampledZp01Buffer;
                    root.currentPredictList = core.predictedZp01List;
                    break;
                default:
                    root.currentDataBuffer = [];
                    root.currentPredictList = [];
            }
        }
    }
}
