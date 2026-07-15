pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

Item {
    id: root

    property string appName: ""
    property var appIcon: "application-x-executable"
    property real baseSize: 48
    property real currentScale: 1.0
    property real crossIconExtent: scaledSize
    property bool isVertical: false
    property int location: PlasmaCore.Types.Floating
    property bool isRunning: false
    property bool isActive: false
    property bool isStarting: false
    property int launchAnimation: 1

    readonly property real scaledSize: baseSize * currentScale
    readonly property real indicatorSize: 3
    readonly property real indicatorGap: 2
    readonly property real crossExtent: crossIconExtent + indicatorGap + indicatorSize
    readonly property bool indicatorAtStart: (!isVertical
        && location === PlasmaCore.Types.TopEdge)
        || (isVertical && location === PlasmaCore.Types.LeftEdge)

    width: isVertical ? crossExtent : scaledSize
    height: isVertical ? scaledSize : crossExtent
    z: Math.round(currentScale * 100)

    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: appName
    Accessible.description: isRunning ? i18n("Läuft") : i18n("Starter")
    Accessible.onPressAction: root.clicked()

    signal clicked()
    signal newInstanceRequested()
    signal contextMenuRequested()

    SystemPalette {
        id: qtPalette

        colorGroup: SystemPalette.Active
    }

    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()
    Keys.onMenuPressed: root.contextMenuRequested()

    SequentialAnimation {
        id: clickBounceAnimation

        NumberAnimation {
            target: iconContainer
            property: "bounceOffset"
            to: 3
            duration: 100
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: iconContainer
            property: "bounceOffset"
            to: 0
            duration: 140
            easing.type: Easing.InQuad
        }
    }

    SequentialAnimation {
        id: startupBounceAnimation

        running: root.launchAnimation === 1 && root.isStarting
        loops: Animation.Infinite

        onRunningChanged: {
            if (running) {
                clickBounceAnimation.stop();
            } else if (!clickBounceAnimation.running) {
                iconContainer.bounceOffset = 0;
            }
        }

        NumberAnimation {
            target: iconContainer
            property: "bounceOffset"
            to: 4
            duration: 120
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: iconContainer
            property: "bounceOffset"
            to: 0
            duration: 170
            easing.type: Easing.InQuad
        }

        PauseAnimation { duration: 110 }
    }

    Item {
        id: iconContainer

        property real bounceOffset: 0

        width: root.scaledSize
        height: root.scaledSize
        x: {
            if (!root.isVertical) {
                return 0;
            }
            if (root.indicatorAtStart) {
                return root.indicatorSize + root.indicatorGap;
            }
            if (root.location === PlasmaCore.Types.RightEdge) {
                return root.crossIconExtent - width;
            }
            return (root.crossIconExtent - width) / 2;
        }
        y: {
            if (root.isVertical) {
                return 0;
            }
            if (root.indicatorAtStart) {
                return root.indicatorSize + root.indicatorGap;
            }
            if (root.location === PlasmaCore.Types.BottomEdge) {
                return root.crossIconExtent - height;
            }
            return (root.crossIconExtent - height) / 2;
        }

        transform: Translate {
            x: {
                if (!root.isVertical) {
                    return 0;
                }
                if (root.location === PlasmaCore.Types.RightEdge) {
                    return -iconContainer.bounceOffset;
                }
                return iconContainer.bounceOffset;
            }
            y: {
                if (root.isVertical) {
                    return 0;
                }
                if (root.location === PlasmaCore.Types.TopEdge) {
                    return iconContainer.bounceOffset;
                }
                return -iconContainer.bounceOffset;
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: 6
            color: "transparent"
            border.color: qtPalette.highlight
            border.width: 2
            visible: root.activeFocus
        }

        Kirigami.Icon {
            anchors.fill: parent
            anchors.margins: 0
            source: root.appIcon || "application-x-executable"
            roundToIconSize: false
            smooth: true
        }

        HoverHandler {
            id: iconHover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            gesturePolicy: TapHandler.ReleaseWithinBounds

            onTapped: {
                root.forceActiveFocus();
                root.clicked();
            }
        }

        TapHandler {
            acceptedButtons: Qt.MiddleButton
            gesturePolicy: TapHandler.ReleaseWithinBounds

            onTapped: {
                root.forceActiveFocus();
                root.newInstanceRequested();
            }
        }

        TapHandler {
            acceptedButtons: Qt.RightButton
            gesturePolicy: TapHandler.ReleaseWithinBounds

            onTapped: {
                root.forceActiveFocus();
                root.contextMenuRequested();
            }
        }

        QQC2.ToolTip.visible: iconHover.hovered && root.appName.length > 0
        QQC2.ToolTip.text: root.appName
        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
    }

    Rectangle {
        id: activeIndicator

        width: root.isVertical ? root.indicatorSize : (root.isActive ? 9 : 6)
        height: root.isVertical ? (root.isActive ? 9 : 6) : root.indicatorSize
        radius: Math.min(width, height) / 2
        color: root.isActive ? qtPalette.highlight : qtPalette.windowText
        opacity: root.isActive ? 1.0 : 0.66
        visible: root.isRunning
        x: {
            if (!root.isVertical) {
                return (root.width - width) / 2;
            }
            return root.indicatorAtStart
                ? 0 : root.crossIconExtent + root.indicatorGap;
        }
        y: {
            if (root.isVertical) {
                return (root.height - height) / 2;
            }
            return root.indicatorAtStart
                ? 0 : root.crossIconExtent + root.indicatorGap;
        }

        Behavior on width {
            NumberAnimation { duration: Kirigami.Units.shortDuration }
        }
        Behavior on height {
            NumberAnimation { duration: Kirigami.Units.shortDuration }
        }
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.shortDuration }
        }
    }

    function triggerBounce() {
        if (launchAnimation === 1 && !isStarting) {
            clickBounceAnimation.restart();
        }
    }
}
