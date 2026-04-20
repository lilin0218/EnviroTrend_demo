import QtQuick 2.11
import QtQuick.Layouts 1.3
import "../common"
import "../pages/DashboardPage"
import "../pages/TrendPage"
import "../pages/LogPage"

Item {
    id: contentRoot
    width: 800.0
    height: 350.0 // 480 (全屏) - 45 (顶栏) - 85 (底栏) = 350

    // 接收外部的索引
    property int currentIndex: 0

    // 使用 StackLayout 管理多页面
    StackLayout {
        id: layout
        anchors.fill: parent
        currentIndex: contentRoot.currentIndex

        // 页面切换时的淡入淡出效果（增强特斯拉感）
        onCurrentIndexChanged: {
            fadeAnim.restart()
        }

        NumberAnimation {
            id: fadeAnim
            target: layout
            property: "opacity"
            from: 0.2; to: 1.0
            duration: Theme.animDuration
        }

        // --- 页面索引 0：环境数据 (Dashboard) ---
        Rectangle {
            id: pageDash
            color: "transparent" // 暂时占位

            // 背景图
            Image {
                anchors.fill: parent
                source: "qrc:/res/bg/bg_black.png"
                opacity: 0.5
            }

            DashboardPage {
                id: dashBoardPage
                anchors.fill: parent
            }
        }

        // --- 页面索引 1：历史预测 (History) ---
        Rectangle {
            id: pageHistory
            color: "transparent"

            // 背景图
            Image {
                anchors.fill: parent
                source: "qrc:/res/bg/bg_blue.png"
                opacity: 0.5
            }

            TrendPage {
                id: trendPage
                anchors.fill: parent
            }
        }

        // --- 页面索引 2：系统日志 (Log) ---
        Rectangle {
            id: pageLog
            color: "transparent"

            // 背景图
            Image {
                anchors.fill: parent
                source: "qrc:/res/bg/bg_green.png"
                opacity: 0.5
            }

            LogPage {
                id: logPage
                anchors.fill: parent
            }
        }

        // --- 页面索引 3：系统设置 (Settings) ---
        Rectangle {
            id: pageSettings
            color: "transparent"

            // 背景图
            Image {
                anchors.fill: parent
                source: "qrc:/res/bg/bg_purple.png"
                opacity: 0.5
            }

            Text {
                text: "System Settings"
                color: Theme.textSecondary
                anchors.centerIn: parent
                font.pixelSize: Theme.sizeTitle
            }
        }

        // --- 页面索引 4：关于软件 (About) ---
        Rectangle {
            id: pageAbout
            color: "transparent"

            // 背景图
            Image {
                anchors.fill: parent
                source: "qrc:/res/bg/bg_red.png"
                opacity: 0.5
            }

            Text {
                text: "About EnviroTrend v1.0"
                color: Theme.textSecondary
                anchors.centerIn: parent
                font.pixelSize: Theme.sizeTitle
            }
        }
    }
}
