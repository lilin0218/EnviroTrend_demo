import QtQuick 2.11
import QtQuick.Controls 2.4
import QtQuick.Layouts 1.3
import "../../common"

Rectangle {
    id: cardRoot
    radius: Theme.borderRadius

    property string label: ""
    property string unit: ""
    property string value: "--"
    property string iconSource: ""
    property real defaultMin: 0
    property real defaultMax: 100

    property real minThreshold: defaultMin
    property real maxThreshold: defaultMax

    color: isAlarm ? Qt.rgba(1, 0.23, 0.19, 0.15) : Qt.rgba(1, 1, 1, 0.1)
    border.color: isAlarm ? Theme.accentRed : Theme.accentBlue
    border.width: isAlarm ? 1.5 : 1.5

    property bool isAlarm: {
        var num = parseFloat(value)
        if (isNaN(num)) return false
        return num < minThreshold || num > maxThreshold
    }

    Row {
        anchors.fill: parent
        anchors.margins: cardRoot.width * 0.06
        spacing: cardRoot.width * 0.04

        Item {
            width: parent.height * 0.6; height: width
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.fill: parent
                source: iconSource
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
//            spacing: cardRoot.height * 0.05

            Text {
                text: cardRoot.label
                color: Theme.textSecondary
                font.pixelSize: cardRoot.height * 0.13
            }

            Row {
                spacing: 4

                Text {
                    text: cardRoot.value
                    color: isAlarm ? Theme.accentRed : Theme.textMain
                    font.bold: true
                    font.pixelSize: cardRoot.height * 0.2
                }

                Text {
                    text: cardRoot.unit
                    color: Theme.textSecondary
                    font.pixelSize: cardRoot.height * 0.1
                }
            }

            Row {
                spacing: 4

                Text {
                    text: isAlarm ? "⚠" : "✓"
                    color: isAlarm ? Theme.accentRed : Theme.accentGreen
                    font.pixelSize: cardRoot.height * 0.1
                }

                Text {
                    text: isAlarm ? "预警" : "正常"
                    color: isAlarm ? Theme.accentRed : Theme.accentGreen
                    font.pixelSize: cardRoot.height * 0.08
                }
            }

            Row {
                spacing: 8
                anchors.topMargin: cardRoot.height * 0.03

                Column {
                    spacing: 2

                    Text {
                        text: "最小"
                        color: Theme.textDisabled
                        font.pixelSize: cardRoot.height * 0.06
                    }

                    TextField {
                        id: minInput
                        width: cardRoot.width * 0.22
                        height: cardRoot.height * 0.3
                        text: minThreshold.toFixed(1)
                        color: Theme.textMain
                        background: Rectangle {
                            color: Theme.mainBg
                            radius: 3
                            border.color: Theme.borderLight
                            border.width: 1
                        }
                        font.pixelSize: cardRoot.height * 0.08
                        inputMethodHints: Qt.ImhFormattedNumbersOnly

                        onEditingFinished: {
                            var val = parseFloat(text)
                            if (!isNaN(val)) {
                                cardRoot.minThreshold = val
                            } else {
                                text = cardRoot.minThreshold.toFixed(1)
                            }
                        }
                    }
                }

                Text {
                    text: "-"
                    color: Theme.textDisabled
                    font.pixelSize: cardRoot.height * 0.12
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    spacing: 2

                    Text {
                        text: "最大"
                        color: Theme.textDisabled
                        font.pixelSize: cardRoot.height * 0.06
                    }

                    TextField {
                        id: maxInput
                        width: cardRoot.width * 0.22
                        height: cardRoot.height * 0.3
                        text: maxThreshold.toFixed(1)
                        color: Theme.textMain
                        background: Rectangle {
                            color: Theme.mainBg
                            radius: 3
                            border.color: Theme.borderLight
                            border.width: 1
                        }
                        font.pixelSize: cardRoot.height * 0.08
                        inputMethodHints: Qt.ImhFormattedNumbersOnly

                        onEditingFinished: {
                            var val = parseFloat(text)
                            if (!isNaN(val)) {
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
}
