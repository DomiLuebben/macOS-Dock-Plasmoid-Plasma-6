import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

Item {
    id: root

    property real progressValue: 0.0
    property bool indeterminate: false
    property bool completing: false
    property real displayedProgress: Math.max(0, Math.min(1, progressValue))
    property real indeterminateRotation: 0
    property real completionOpacity: 1

    anchors.fill: parent
    enabled: false
    opacity: completionOpacity

    SequentialAnimation {
        id: completionAnimation

        PauseAnimation { duration: 90 }
        NumberAnimation {
            target: root
            property: "completionOpacity"
            from: 1
            to: 0
            duration: 360
            easing.type: Easing.InCubic
        }
    }

    Behavior on displayedProgress {
        NumberAnimation {
            duration: Kirigami.Units.shortDuration
            easing.type: Easing.OutCubic
        }
    }

    NumberAnimation on indeterminateRotation {
        from: 0
        to: 360
        duration: Math.max(1, Kirigami.Units.longDuration * 4)
        loops: Animation.Infinite
        running: root.indeterminate && Kirigami.Units.longDuration > 0
    }

    onCompletingChanged: {
        if (completing) {
            completionOpacity = 1;
            completionAnimation.restart();
        } else {
            completionAnimation.stop();
            completionOpacity = 1;
        }
    }
    Component.onCompleted: {
        if (completing) {
            completionAnimation.restart();
        }
    }

    readonly property real ringPadding:
        Math.max(2, Math.round(Math.min(width, height) * 0.05))
    readonly property real ringDiameter:
        Math.max(12, Math.min(width, height) - ringPadding * 2)
    readonly property real strokeWidth:
        Math.max(2, Math.round(ringDiameter * 0.09))
    readonly property real radius: (ringDiameter - strokeWidth) / 2

    Shape {
        anchors.centerIn: parent
        width: root.ringDiameter
        height: root.ringDiameter

        ShapePath {
            strokeColor: Qt.rgba(0, 0, 0, 0.52)
            fillColor: Qt.rgba(0, 0, 0, 0.28)
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.ringDiameter / 2
                centerY: root.ringDiameter / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: Kirigami.Theme.highlightColor
            fillColor: "transparent"
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.ringDiameter / 2
                centerY: root.ringDiameter / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: root.indeterminate
                    ? root.indeterminateRotation - 90 : -90
                sweepAngle: root.indeterminate
                    ? 96 : root.displayedProgress * 360
            }
        }
    }
}
