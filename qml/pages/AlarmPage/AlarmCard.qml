import QtQuick 2.11
import QtQuick.Controls 2.4
import QtQuick.Layouts 1.3
import "../../common"

Rectangle {
    id: cardRoot

    property string label: ""
    property string unit: ""
    property string value: "--"
    property string iconSource: ""
    property int sensorIndex: -1  // 传感器索引，用于与CoreManager绑定

    property real defaultMin: 0
    property real defaultMax: 100

    property real minThreshold: {
        // 从CoreManager获取阈值
        if (sensorIndex >= 0) {
            var thresholds = core.sensorThresholds
            if (thresholds.length > sensorIndex) {
                var t = thresholds[sensorIndex]
                return t.min !== undefined ? t.min : defaultMin
            }
        }
        return defaultMin
    }

    property real maxThreshold: {
        // 从CoreManager获取阈值
        if (sensorIndex >= 0) {
            var thresholds = core.sensorThresholds
            if (thresholds.length > sensorIndex) {
                var t = thresholds[sensorIndex]
                return t.max !== undefined ? t.max : defaultMax
            }
        }
        return defaultMax
    }

    property bool isAlarm: {
        var num = parseFloat(value)
        if (isNaN(num))
            return false

        return num < minThreshold || num > maxThreshold
    }

    radius: Theme.borderRadius

    color: isAlarm
           ? Qt.rgba(1, 0.23, 0.19, 0.12)
           : Qt.rgba(1, 1, 1, 0.08)

    border.color: isAlarm
                  ? Theme.accentRed
                  : Theme.borderLight

    border.width: 1.5

    RowLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 20

        Item {
            Layout.preferredWidth: parent.height * 0.7
            Layout.preferredHeight: parent.height * 0.7

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: "transparent"

                Image {
                    anchors.centerIn: parent
                    width: parent.width * 0.8
                    height: parent.height * 0.8
                    source: iconSource
                    fillMode: Image.PreserveAspectFit
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            Text {
                text: cardRoot.label
                color: Theme.textSecondary
                font.pixelSize: cardRoot.height * 0.15
            }

            Text {
                text: cardRoot.value + " " + cardRoot.unit
                color: isAlarm ? Theme.accentRed : Theme.textMain
                font.bold: true
                font.pixelSize: cardRoot.height * 0.22
            }

            Rectangle {
                radius: 8
                height: cardRoot.height * 0.15
                width: statusText.contentWidth + 16

                color: isAlarm
                       ? Qt.rgba(1, 0.23, 0.19, 0.18)
                       : Qt.rgba(0, 1, 0, 0.12)

                Text {
                    id: statusText
                    anchors.centerIn: parent

                    text: isAlarm ? "预警" : "正常"

                    color: isAlarm
                           ? Theme.accentRed
                           : Theme.accentGreen

                    font.pixelSize: cardRoot.height * 0.09
                    font.bold: true
                }
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 8

            Text {
                text: "阈值范围"
                color: Theme.textSecondary
                font.pixelSize: cardRoot.height * 0.13
                font.bold: true
                horizontalAlignment: Text.AlignRight
            }

            RowLayout {
                spacing: 6

                TextField {
                    id: minInput

                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 32

                    text: minThreshold.toFixed(1)

                    color: Theme.textMain
                    font.pixelSize: cardRoot.height * 0.12
                    font.bold: true
                    horizontalAlignment: Text.AlignCenter

                    inputMethodHints: Qt.ImhFormattedNumbersOnly

                    background: Rectangle {
                        radius: 4
                        color: Theme.mainBg

                        border.color: Theme.borderLight
                        border.width: 1
                    }

                    onEditingFinished: {
                        var val = parseFloat(text)

                        if (!isNaN(val) && sensorIndex >= 0) {
                            // 更新CoreManager中的阈值
                            core.setSensorThreshold(sensorIndex, val, cardRoot.maxThreshold)
                        } else if (!isNaN(val)) {
                            cardRoot.minThreshold = val
                        } else {
                            text = cardRoot.minThreshold.toFixed(1)
                        }
                    }
                }

                Text {
                    text: "~"
                    color: Theme.textSecondary
                    font.pixelSize: cardRoot.height * 0.12
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                }

                TextField {
                    id: maxInput

                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 32

                    text: maxThreshold.toFixed(1)

                    color: Theme.textMain
                    font.pixelSize: cardRoot.height * 0.12
                    font.bold: true
                    horizontalAlignment: Text.AlignCenter

                    inputMethodHints: Qt.ImhFormattedNumbersOnly

                    background: Rectangle {
                        radius: 4
                        color: Theme.mainBg

                        border.color: Theme.borderLight
                        border.width: 1
                    }

                    onEditingFinished: {
                        var val = parseFloat(text)

                        if (!isNaN(val) && sensorIndex >= 0) {
                            // 更新CoreManager中的阈值
                            core.setSensorThreshold(sensorIndex, cardRoot.minThreshold, val)
                        } else if (!isNaN(val)) {
                            cardRoot.maxThreshold = val
                        } else {
                            text = cardRoot.maxThreshold.toFixed(1)
                        }
                    }
                }
            }
        }
    }
}