pragma Singleton // 声明为单例，全局唯一
import QtQuick 2.11

QtObject {
    // --- 核心配色体系 (参考 Tesla Dark Mode) ---
    readonly property color mainBg: "#000000"           // 纯黑背景
    readonly property color cardBg: "#1C1C1E"           // 内容卡片背景（深灰）
    readonly property color navBg: "#121212"            // 底部导航栏背景

    readonly property color accentBlue: "#2196F3"       // 特斯拉电蓝色（主交互色）
    readonly property color accentGreen: "#4CAF50"      // 正常状态/环保色
    readonly property color accentRed: "#FF3B30"        // 告警/错误红色
    readonly property color accentPurple: "#AF52DE"     // 预测/LSTM 专用紫色

    readonly property color textMain: "#FFFFFF"         // 主文字颜色
    readonly property color textSecondary: "#8E8E93"    // 次要文字颜色（灰色）
    readonly property color textDisabled: "#48484A"     // 禁用状态文字颜色

    // --- 边框与阴影 ---
    readonly property color borderLight: "#38383A"      // 浅色边框
    readonly property double borderRadius: 12.0         // 卡片通用圆角

    // --- 字体尺寸体系 (统一使用 double) ---
    // 针对 800*480 屏幕优化
    readonly property double sizeStatusBar: 16.0        // 顶部信息栏字号
    readonly property double sizeNavLabel: 14.0         // 导航栏文字字号
    readonly property double sizeBody: 18.0             // 正文字号
    readonly property double sizeSubTitle: 22.0         // 小标题字号
    readonly property double sizeTitle: 28.0            // 页面标题字号
    readonly property double sizeHero: 56.0             // 巨大数字（实时温湿度）字号

    // --- 动画参数 ---
    readonly property int animDuration: 500             // 通用动画时长 (ms)
    readonly property int flowDuration: 500             // 导航栏流转动画时长
}
