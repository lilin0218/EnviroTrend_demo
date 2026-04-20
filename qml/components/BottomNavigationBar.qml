import QtQuick 2.11
import "../common"

Rectangle {
    id: navBar
    width: 800.0
    height: 85.0
    color: Theme.navBg

    property int currentIndex: 0
    readonly property int buttonCount: 5

    // --- 1. 背景流转滑块（使用分离出的组件） ---
    NavIndicator {
        id: flowIndicator
        currentIndex: navBar.currentIndex
        containerWidth: navBar.width
        containerHeight: navBar.height
        itemCount: navBar.buttonCount
    }

    // --- 2. 按钮行 ---
    Row {
        anchors.fill: parent

        NavButton {
            iconBaseName: "navDashboard"
            labelText: "仪表盘"
            isActive: currentIndex === 0
            onClicked: currentIndex = 0
        }

        NavButton {
            iconBaseName: "navHistory"
            labelText: "历史数据"
            isActive: currentIndex === 1
            onClicked: currentIndex = 1
        }

        NavButton {
            iconBaseName: "navLocation"
            labelText: "地理位置"
            isActive: currentIndex === 2
            onClicked: currentIndex = 2
        }

        NavButton {
            iconBaseName: "navSettings"
            labelText: "系统设置"
            isActive: currentIndex === 3
            onClicked: currentIndex = 3
        }

        NavButton {
            iconBaseName: "navAbout"
            labelText: "关于设备"
            isActive: currentIndex === 4
            onClicked: currentIndex = 4
        }
    }

    // 顶部装饰线
    Rectangle {
        width: parent.width; height: 1.0
        color: Theme.borderLight
        anchors.top: parent.top
    }
}
