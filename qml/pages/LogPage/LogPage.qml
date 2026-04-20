import QtQuick 2.11
import QtQuick.Controls 2.4
import QtQuick.Layouts 1.3
import "../../common"

Item {
    id: pageRoot
    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        anchors.margins: 10
        color: Theme.cardBg
        opacity: 0.8
        radius: Theme.borderRadius
        border.color: Theme.borderLight
        border.width: 2

        ListView {
            id: logListView
            anchors.fill: parent
            anchors.margins: 8
            clip: true
            
            // 来自core的logList
            model: core ? core.logList : []
            delegate: logDelegate
            spacing: 2
            
            ScrollBar.vertical: ScrollBar {
                width: 6
                policy: ScrollBar.AlwaysOn
            }
            
            onCountChanged: {
                if (count > 0) {
                    positionViewAtEnd()
                }
            }
        }
    }

    Component {
        id: logDelegate
        Item {
            width: logListView.width
            height: 24

            property var logData: {
                var item = modelData || {}
                var d = {}
                d.timestamp = item.hasOwnProperty("timestamp") ? item.timestamp : ""
                d.level = item.hasOwnProperty("level") ? item.level : "UNKNOWN"
                d.module = item.hasOwnProperty("module") ? item.module : ""
                d.message = item.hasOwnProperty("message") ? item.message : ""
                d.color = item.hasOwnProperty("color") ? item.color : "#888888"
                return d
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 4
                spacing: 8

                Text {
                    text: index + 1
                    color: Theme.textDisabled
                    font.pixelSize: 8
                    width: 24
                }

                Text {
                    text: logData.timestamp
                    color: Theme.textSecondary
                    font.pixelSize: 8
                    width: 100
                    elide: Text.ElideRight
                }

                Text {
                    text: "[" + logData.level + "]"
                    color: logData.color
                    font.pixelSize: 8
                    font.bold: true
                    width: 50
                }

                Text {
                    text: logData.module
                    color: Theme.accentBlue
                    font.pixelSize: 8
                    width: 50
                }

                Text {
                    text: logData.message
                    color: Theme.textMain
                    font.pixelSize: 8
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
        }
    }
}
