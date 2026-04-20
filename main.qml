import QtQuick 2.11
import QtQuick.Window 2.11
import QtQuick.Layouts 1.3
import Qt.labs.platform 1.0
import QtQuick.Controls 2.4
import "qrc:/qml/common"
import "qrc:/qml/components"
import "./qml/pages/HelloPage"

Window {
    visible: true
    width: 800
    height: 480
    title: qsTr("EnviroTrend - Tesla Style")
    color: Theme.mainBg

    // 错误提示组件
    MessageDialog {
        id: errorDialog
        title: "Error"
        text: "An error occurred"
        buttons: MessageDialog.Ok
        modality: Qt.ApplicationModal
        onAccepted: {
            // 如果是数据库错误，退出程序
            if (text.indexOf("数据库") >= 0 || text.indexOf("database") >= 0) {
                Qt.quit()
            }
        }
    }

    // 加载指示器
    Rectangle {
        id: loadingIndicator
        anchors.fill: parent
        color: Theme.mainBg
        visible: false
        z: 99

        Column {
            anchors.centerIn: parent
            spacing: 20

            Text {
                text: "Loading..."
                color: Theme.textMain
                font.pixelSize: Theme.sizeSubTitle
                horizontalAlignment: Text.AlignHCenter
            }

            BusyIndicator {
                running: loadingIndicator.visible
                anchors.horizontalCenter: parent.horizontalCenter
                width: 60
                height: 60
            }
        }
    }

    ColumnLayout {
        id: mainArea
        anchors.fill: parent
        spacing: 0
        visible: false

        TopStatusBar {
            Layout.fillWidth: true
            Layout.preferredHeight: 45.0
        }

        MainContentStack {
            id: contentStack
            currentIndex: bottomNav.currentIndex
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        BottomNavigationBar {
            id: bottomNav
            Layout.fillWidth: true
            Layout.preferredHeight: 85.0
        }
    }

    // --- 开屏动画层 ---
    HelloPage {
        id: helloArea
        anchors.fill: parent
        z: 100 // 确保在最顶层

        // 增加退出动画
        Behavior on opacity {
            NumberAnimation { duration: 1000 }
        }
    }

    // --- 跳转控制定时器 ---
    Timer {
        id: loadTimer
        interval: 3000 // 缩短启动时间
        running: true
        repeat: false
        onTriggered: {
            helloArea.opacity = 0
            mainArea.visible = true
            // 彻底销毁开屏页以节省显存
            destroyTimer.start()
        }
    }

    Timer {
        id: destroyTimer
        interval: 800
        onTriggered: {
            helloArea.destroy()
        }
    }

    // 连接错误信号
    Connections {
        target: core
        function onErrorOccurred(error) {
            errorDialog.text = error
            errorDialog.open()
            // 如果是数据库错误，立即停止加载动画
            if (error.indexOf("数据库") >= 0 || error.indexOf("database") >= 0) {
                loadingIndicator.visible = false
                loadTimer.stop()
            }
        }
    }
}

