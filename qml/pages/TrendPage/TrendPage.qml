import QtQuick 2.11
import QtQuick.Layouts 1.0
import "../../common"
// 注意：由于 TrendChart 和 SideAnchorBar 在同级目录下，直接引用即可

Rectangle {
    id: root
    color: "transparent"

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // 1. 左侧：导航锚点栏
        SideAnchorBar {
            id: sideBar
            Layout.fillHeight: true
            Layout.preferredWidth: 90

            // 联动逻辑：点击左侧，右侧滚动
            onItemSelected: {
                scrollToSection(index)
            }
        }

        // 2. 右侧：可滚动的图表展示区
        Flickable {
            id: chartFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: chartColumn.height
            clip: true

            // 平滑滚动动画
            Behavior on contentY {
                NumberAnimation {
                    duration: 500
                    easing.type: Easing.OutQuint
                }
            }

            Column {
                id: chartColumn
                width: parent.width
                spacing: 20
                topPadding: 20
                bottomPadding: 100

                // 1. 温度图表
                TrendChart {
                    id: tempChart
                    title: "温度趋势 (°C)"
                    // Y 轴绝对边界
                    limitMinY: 15.0
                    limitMaxY: 25.0
                    // X 轴滑动条上限
                    dataBuffer: core.tempBuffer
                    predictList: core.predictedTempList
                }

                // 2. 湿度图表
                TrendChart {
                    id: humChart
                    title: "湿度趋势 (%)"
                    limitMinY: 50.0
                    limitMaxY: 80.0
                    dataBuffer: core.humBuffer
                    predictList: core.predictedHumList
                }

                // 3. 光照图表
                TrendChart {
                    id: lightChart
                    title: "光照趋势 (V)"
                    limitMinY: 0.0
                    limitMaxY: 3.3
                    dataBuffer: core.lightBuffer
                    predictList: core.predictedLightList
                }

                // 4. MQ135 (气体颗粒物)图表
                TrendChart {
                    id: mq135Chart
                    title: "MQ135 (气体颗粒物)趋势 (ppm)"
                    limitMinY: 0.0
                    limitMaxY: 100.0
                    dataBuffer: core.mq135Buffer
                    predictList: core.predictedMq135List
                }

                // 5. ZP01 (空气质量)图表
                TrendChart {
                    id: zp01Chart
                    title: "ZP01 (空气质量)趋势 (μg/m³)"
                    limitMinY: 0.0
                    limitMaxY: 100.0
                    dataBuffer: core.zp01Buffer
                    predictList: core.predictedZp01List
                }

                // 6. 噪音占位矩形
                Rectangle {
                    width: parent.width
                    height: 300
                    color: "#f0f0f0"
                    border.color: "#d0d0d0"
                    border.width: 1
                    radius: 8
                    
                    Text {
                        anchors.centerIn: parent
                        text: "噪音传感器未启用"
                        font.pointSize: 14
                        color: "#606060"
                    }
                }
            }

            // 联动逻辑：手动滑动右侧时，自动更新左侧的高亮状态
            onMovementEnded: {
                updateSideBarIndex()
            }
        }
    }

    // --- 逻辑函数 ---

    // 滚动到指定索引的图表
    function scrollToSection(index) {
        if (index < chartColumn.children.length) {
            let targetItem = chartColumn.children[index];
            chartFlickable.contentY = targetItem.y;
        }
    }

    // 自动检测当前视口在哪个图表，同步左侧高亮
    function updateSideBarIndex() {
        let currentY = chartFlickable.contentY + 50; // 偏移量，提高识别灵敏度
        for (var i = 0; i < chartColumn.children.length; i++) {
            let item = chartColumn.children[i];
            if (currentY >= item.y && currentY < (item.y + item.height + chartColumn.spacing)) {
                sideBar.currentIndex = i;
                break;
            }
        }
    }
}
