import QtQuick 2.11
import QtQuick.Controls 2.4

Button {
    id: control

    // ===== 自定义属性 =====
    property string shape: "Rect"     // Rect Circle Rhombus
    property color themeColor: "#1a73e8"   // Google Blue
    property real borderWidth: 1
    property color activeBorderColor: "#ffffff"
    property color idleBorderColor: Qt.darker(themeColor, 1.3)

    implicitWidth: 140
    implicitHeight: 44

    contentItem: Text {
        text: control.text
        font.pixelSize: 14
        font.weight: Font.Medium
        color: control.enabled ? "white" : "#aaaaaa"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Item {
        id: bg
        anchors.fill: parent

        Rectangle {
            id: mainShape
            anchors.fill: parent
            anchors.margins: control.shape === "Rhombus" ? 8 : 0

            color: !control.enabled ? "#cccccc"
                 : control.pressed ? Qt.darker(control.themeColor, 1.2)
                 : control.hovered ? Qt.lighter(control.themeColor, 1.1)
                 : control.themeColor

            radius: control.shape === "Circle" ? width/2 : 6
            rotation: control.shape === "Rhombus" ? 45 : 0

            border.width: control.borderWidth
            border.color: (control.hovered || control.pressed)
                          ? control.activeBorderColor
                          : control.idleBorderColor

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            Behavior on border.color {
                ColorAnimation { duration: 120 }
            }
        }

        // ===== Ripple 水波纹 =====
        Rectangle {
            id: ripple
            visible: control.pressed
            anchors.centerIn: parent

            width: 10
            height: width
            radius: width / 2

            color: "#33ffffff"
            opacity: 0.6

            transform: Scale { id: rippleScale; xScale: 0; yScale: 0 }

            SequentialAnimation {
                running: control.pressed
                PropertyAnimation {
                    target: rippleScale
                    property: "xScale"
                    from: 0
                    to: 8
                    duration: 350
                }
            }

            SequentialAnimation {
                running: control.pressed
                PropertyAnimation {
                    target: rippleScale
                    property: "yScale"
                    from: 0
                    to: 8
                    duration: 350
                }
            }

            SequentialAnimation {
                running: control.pressed
                PropertyAnimation {
                    target: ripple
                    property: "opacity"
                    from: 0.6
                    to: 0
                    duration: 350
                }
            }
        }
    }
}
