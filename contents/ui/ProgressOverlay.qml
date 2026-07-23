import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real progressValue: 0.0
    property bool indeterminate: false
    property bool active: true
    signal completionFinished()

    anchors.fill: parent
    enabled: false

    opacity: active ? 1.0 : 0.0
    Behavior on opacity {
        NumberAnimation { duration: 150 }
    }

    readonly property real ringPadding: Math.max(2, Math.round(width * 0.05))
    readonly property real ringDiameter: Math.max(12, Math.min(width, height) - ringPadding * 2)
    readonly property real strokeWidth: Math.max(2, Math.round(ringDiameter * 0.09))
    readonly property real radius: (ringDiameter - strokeWidth) / 2

    NumberAnimation on indeterminateRotation {
        id: spinnerAnim
        from: 0
        to: 360
        duration: 1200
        loops: Animation.Infinite
        running: root.indeterminate && root.active
    }
    property real indeterminateRotation: 0

    Shape {
        id: bgShape
        anchors.centerIn: parent
        width: root.ringDiameter
        height: root.ringDiameter
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeColor: Qt.rgba(0, 0, 0, 0.45)
            fillColor: Qt.rgba(0, 0, 0, 0.30)
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.ringDiameter / 2
                centerY: root.ringDiameter / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: Qt.rgba(1, 1, 1, 0.95)
            fillColor: "transparent"
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.ringDiameter / 2
                centerY: root.ringDiameter / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: root.indeterminate ? root.indeterminateRotation - 90 : -90
                sweepAngle: root.indeterminate ? 90 : Math.max(5, Math.min(360, root.progressValue * 360))
            }
        }
    }
}
