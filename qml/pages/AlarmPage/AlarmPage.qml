import QtQuick 2.11
import QtQuick.Layouts 1.3
import "../../common"

Item {
    id: pageRoot
    anchors.fill: parent

    readonly property double marginSize: width * 0.04
    readonly property double cellSpacing: width * 0.02
    readonly property double cardWidth: (width - (marginSize * 2.0) - cellSpacing) / 2.0
    readonly property double cardHeight: (height - (marginSize * 2.0) - (cellSpacing * 2.0)) / 3.0

    Grid {
        anchors.fill: parent
        anchors.margins: pageRoot.marginSize
        columns: 2
        spacing: pageRoot.cellSpacing

        AlarmCard {
            width: cardWidth; height: cardHeight
            label: "环境温度"
            unit: "°C"
            value: core.tempStr
            iconSource: "qrc:/res/sensor/temp_checked.png"
            sensorIndex: 0
            defaultMin: 15
            defaultMax: 35
        }

        AlarmCard {
            width: cardWidth; height: cardHeight
            label: "相对湿度"
            unit: "%"
            value: core.humStr
            iconSource: "qrc:/res/sensor/hum_checked.png"
            sensorIndex: 1
            defaultMin: 30
            defaultMax: 90
        }

        AlarmCard {
            width: cardWidth; height: cardHeight
            label: "光照"
            unit: "V"
            value: core.lightStr
            iconSource: "qrc:/res/sensor/light_checked.png"
            sensorIndex: 2
            defaultMin: 0
            defaultMax: 3.3
        }

        AlarmCard {
            width: cardWidth; height: cardHeight
            label: "MQ135"
            unit: "ppm"
            value: core.mq135Str
            iconSource: "qrc:/res/sensor/aqi_checked.png"
            sensorIndex: 3
            defaultMin: 0
            defaultMax: 100
        }

        AlarmCard {
            width: cardWidth; height: cardHeight
            label: "ZP01"
            unit: "μg/m³"
            value: core.zp01Str
            iconSource: "qrc:/res/sensor/particle_checked.png"
            sensorIndex: 4
            defaultMin: 0
            defaultMax: 100
        }

        Rectangle {
            width: cardWidth; height: cardHeight
            radius: Theme.borderRadius
            color: Qt.rgba(1, 1, 1, 0.03)
            border.color: "#444444"
            border.width: 1.0

            Row {
                anchors.fill: parent
                anchors.margins: width * 0.06
                spacing: width * 0.04
                opacity: 0.4

                Item {
                    width: parent.height * 0.6; height: width
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        source: "qrc:/res/sensor/noise_checked.png"
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: height * 0.05

                    Text {
                        text: "噪音"
                        color: "#666666"
//                        font.pixelSize: height * 0.13
                    }

                    Text {
                        text: "已禁用"
                        color: "#888888"
                        font.bold: true
//                        font.pixelSize: height * 0.2
                    }
                }
            }
        }
    }
}
