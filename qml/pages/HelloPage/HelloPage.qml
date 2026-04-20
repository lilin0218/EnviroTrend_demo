import QtQuick 2.11
import QtQuick.Controls 1.4
import QtQuick.Controls.Styles 1.4
import "../../common"

Rectangle {
    id: helloPage
    anchors.fill: parent

    // --- 暴露出的时长变量 ---
    property int duration: 500

    // 背景
    Image {
        source: "qrc:/res/bg/bg_sunflower.png"
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        Rectangle { anchors.fill: parent; color: "black"; opacity: 0.4 }
    }

    Column {
        anchors.centerIn: parent
        spacing: 30

        // LOGO
        Image {
            id: logo
            source: "qrc:/res/logo/logo_transparentbg.png"
            width: height; height: helloPage.height / 4
            anchors.horizontalCenter: parent.horizontalCenter
            fillMode: Image.PreserveAspectFit
            opacity: 0; scale: 0.5

            Component.onCompleted: logoAnim.start()

            ParallelAnimation {
                id: logoAnim
                // 使用 duration 的 1/5 时间完成 Logo 进场，体感更灵敏
                NumberAnimation { target: logo; property: "opacity"; to: 1; duration: helloPage.duration; easing.type: Easing.OutCubic }
                NumberAnimation { target: logo; property: "scale"; to: 1; duration: helloPage.duration; easing.type: Easing.OutBack }
            }
        }

        // 旋转图标
        Image {
            id: loadingIcon
            source: "qrc:/res/splash/loading.png"
            width: height; height: helloPage.height / 10
            anchors.horizontalCenter: parent.horizontalCenter

            RotationAnimator {
                target: loadingIcon; from: 0; to: 360
                duration: 1500 // 旋转速度保持独立，不受总时长影响，否则太慢会显得卡顿
                running: true; loops: Animation.Infinite
            }
        }

        // 进度条
        ProgressBar {
            id: progressBar
            width: 300; height: 6
            anchors.horizontalCenter: parent.horizontalCenter
            minimumValue: 0; maximumValue: 100
            value: 0

            style: ProgressBarStyle {
                background: Rectangle { color: Qt.rgba(1, 1, 1, 0.2); radius: 3 }
                progress: Rectangle {
                    width: progressBar.width * (progressBar.value - progressBar.minimumValue) / (progressBar.maximumValue - progressBar.minimumValue)
                    height: progressBar.height; radius: 3; color: Theme.accentBlue
                }
            }

            // 进度条动画时长绑定到全局 duration
            NumberAnimation on value {
                from: 0; to: 100;
                duration: helloPage.duration
                easing.type: Easing.Linear // 使用线性，让加载感更匀称
            }
        }

        Text {
            text: "正在初始化传感器系统..."
            color: "white"; font.pixelSize: 16
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
