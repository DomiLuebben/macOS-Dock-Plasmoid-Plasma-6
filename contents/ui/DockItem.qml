pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.layershell as LayerShell
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
    property real screenEdgeMargin: 0
    property bool isRunning: false
    property bool isActive: false
    property bool isStarting: false
    property bool dragEnabled: true
    property int launchAnimation: 1
    property bool previewAvailable: isRunning

    readonly property real scaledSize: baseSize * currentScale
    readonly property real indicatorSize: 3
    readonly property real indicatorGap: 2
    readonly property real crossExtent: crossIconExtent + indicatorGap + indicatorSize
    readonly property bool indicatorAtStart: (!isVertical
        && location === PlasmaCore.Types.TopEdge)
        || (isVertical && location === PlasmaCore.Types.LeftEdge)

    property bool isDragging: false
    property bool dropTarget: false
    property real dragOffsetX: 0
    property real dragOffsetY: 0
    property real dragVisualProgress:
        isDragging || dropTarget ? 1.0 : 0.0

    Behavior on dragOffsetX {
        enabled: !root.isDragging
        NumberAnimation {
            duration: 165
            easing.type: Easing.OutCubic
        }
    }

    Behavior on dragOffsetY {
        enabled: !root.isDragging
        NumberAnimation {
            duration: 165
            easing.type: Easing.OutCubic
        }
    }

    Behavior on dragVisualProgress {
        NumberAnimation {
            duration: root.isDragging ? 110 : 180
            easing.type: root.isDragging
                ? Easing.OutCubic : Easing.InOutCubic
        }
    }

    width: isVertical ? crossExtent : scaledSize
    height: isVertical ? scaledSize : crossExtent
    z: isDragging ? 9999 : Math.round(currentScale * 100)

    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: appName
    Accessible.description: isRunning ? i18n("Running") : i18n("Launcher")
    Accessible.onPressAction: root.clicked()

    property var windowsList: []
    property bool previewOpen: false
    property bool previewDataRequested: false
    property bool previewPositionPending: false
    readonly property bool iconHovered: iconHover.hovered
    readonly property bool previewHovered: previewHover.hovered
    readonly property bool hasWindowPreviews: root.isRunning
        && Boolean(root.windowsList && root.windowsList.length > 0)

    signal clicked()
    signal newInstanceRequested()
    signal contextMenuRequested()
    signal dragStarted(real sceneX, real sceneY)
    signal dragMoved(real sceneX, real sceneY)
    signal dragEnded()
    signal windowActivated(var modelIndex)
    signal windowClosed(var modelIndex)
    signal previewVisibilityChanged(bool visible)

    onHasWindowPreviewsChanged: {
        if (root.hasWindowPreviews && root.iconHovered
                && root.previewDataRequested && !root.previewOpen
                && !root.isDragging) {
            root.setPreviewOpen(true);
        } else if (!root.hasWindowPreviews) {
            root.setPreviewOpen(false);
        }
    }

    onIconHoveredChanged: {
        if (root.iconHovered && root.previewAvailable
                && !root.isDragging) {
            previewCloseTimer.stop();
            if (!root.previewOpen && !root.previewDataRequested) {
                previewOpenTimer.restart();
            }
        } else {
            previewOpenTimer.stop();
            root.schedulePreviewClose();
        }
    }

    onPreviewHoveredChanged: {
        if (root.previewHovered) {
            previewCloseTimer.stop();
        } else {
            root.schedulePreviewClose();
        }
    }

    onIsDraggingChanged: {
        if (root.isDragging) {
            previewOpenTimer.stop();
            previewCloseTimer.stop();
            root.setPreviewOpen(false);
        }
    }

    onPreviewAvailableChanged: {
        if (!root.previewAvailable) {
            previewOpenTimer.stop();
            previewCloseTimer.stop();
            root.setPreviewOpen(false);
        } else if (root.iconHovered && !root.isDragging) {
            previewOpenTimer.restart();
        }
    }

    Timer {
        id: previewOpenTimer

        interval: Kirigami.Units.toolTipDelay
        repeat: false
        onTriggered: {
            if (root.iconHovered && root.previewAvailable
                    && !root.isDragging) {
                root.previewDataRequested = true;
                if (root.hasWindowPreviews) {
                    root.setPreviewOpen(true);
                } else {
                    root.previewDataRequested = false;
                }
            }
        }
    }

    Timer {
        id: previewCloseTimer

        interval: 180
        repeat: false
        onTriggered: {
            if (!root.iconHovered && !root.previewHovered) {
                root.setPreviewOpen(false);
            }
        }
    }

    Window {
        id: previewWindow

        property real placementLeft: 0
        property real placementTop: 0
        property real placementRight: 0
        property real placementBottom: 0

        flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
        color: "transparent"
        width: previewContent.implicitWidth
            + 2 * Kirigami.Units.smallSpacing
        height: previewContent.implicitHeight
            + 2 * Kirigami.Units.smallSpacing
        visible: false

        LayerShell.Window.scope: "macosdock-preview"
        LayerShell.Window.anchors: {
            if (root.isVertical) {
                return (root.location === PlasmaCore.Types.LeftEdge
                    ? LayerShell.Window.AnchorLeft
                    : LayerShell.Window.AnchorRight)
                    | LayerShell.Window.AnchorTop;
            }
            return LayerShell.Window.AnchorLeft
                | (root.location === PlasmaCore.Types.TopEdge
                    ? LayerShell.Window.AnchorTop
                    : LayerShell.Window.AnchorBottom);
        }
        LayerShell.Window.margins.left: placementLeft
        LayerShell.Window.margins.top: placementTop
        LayerShell.Window.margins.right: placementRight
        LayerShell.Window.margins.bottom: placementBottom
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.keyboardInteractivity:
            LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.activateOnShow: false
        LayerShell.Window.wantsToBeOnActiveScreen: true

        PlasmaCore.DialogBackground {
            anchors.fill: parent
        }

        onVisibleChanged: {
            if (visible) {
                root.schedulePreviewPosition();
            }
            if (!visible && root.previewOpen) {
                root.previewOpen = false;
                root.previewDataRequested = false;
                root.previewVisibilityChanged(false);
            }
        }
        onWidthChanged: {
            if (visible) {
                root.schedulePreviewPosition();
            }
        }
        onHeightChanged: {
            if (visible) {
                root.schedulePreviewPosition();
            }
        }
        onScreenChanged: {
            if (visible) {
                root.schedulePreviewPosition();
            }
        }

        WindowPreviewToolTip {
            id: previewContent

            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            windowsList: root.windowsList
            appIcon: root.appIcon
            appName: root.appName
            captureRequested: previewWindow.visible

            HoverHandler {
                id: previewHover
            }

            onWindowActivated: (modelIndex) => {
                root.setPreviewOpen(false);
                root.windowActivated(modelIndex);
            }
            onWindowClosed: (modelIndex) => root.windowClosed(modelIndex)
        }
    }

    Connections {
        target: root
        enabled: previewWindow.visible

        function onXChanged() {
            root.schedulePreviewPosition();
        }

        function onYChanged() {
            root.schedulePreviewPosition();
        }

        function onLocationChanged() {
            root.schedulePreviewPosition();
        }

        function onScreenEdgeMarginChanged() {
            root.schedulePreviewPosition();
        }
    }

    Connections {
        target: iconContainer
        enabled: previewWindow.visible

        function onXChanged() {
            root.schedulePreviewPosition();
        }

        function onYChanged() {
            root.schedulePreviewPosition();
        }

        function onWidthChanged() {
            root.schedulePreviewPosition();
        }

        function onHeightChanged() {
            root.schedulePreviewPosition();
        }
    }

    Connections {
        target: iconContainer.Window.window
        enabled: previewWindow.visible

        function onWidthChanged() {
            root.schedulePreviewPosition();
        }

        function onHeightChanged() {
            root.schedulePreviewPosition();
        }

        function onScreenChanged() {
            root.schedulePreviewPosition();
        }
    }

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
        transformOrigin: Item.Center
        scale: 1.0 + root.dragVisualProgress * 0.08
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

        opacity: 1.0 - root.dragVisualProgress * 0.06

        transform: Translate {
            x: {
                var base = 0;
                if (root.isVertical) {
                    if (root.location === PlasmaCore.Types.RightEdge) {
                        base = -iconContainer.bounceOffset;
                    } else {
                        base = iconContainer.bounceOffset;
                    }
                }
                return base + root.dragOffsetX;
            }
            y: {
                var base = 0;
                if (!root.isVertical) {
                    if (root.location === PlasmaCore.Types.TopEdge) {
                        base = iconContainer.bounceOffset;
                    } else {
                        base = -iconContainer.bounceOffset;
                    }
                }
                return base + root.dragOffsetY;
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

        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            z: -1
            radius: 9
            color: qtPalette.highlight
            opacity: root.dragVisualProgress * 0.18
            scale: 0.92 + root.dragVisualProgress * 0.08
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

        DragHandler {
            id: dragHandler

            enabled: root.dragEnabled
            acceptedButtons: Qt.LeftButton
            target: null

            onActiveChanged: {
                if (active) {
                    root.isDragging = true;
                    root.forceActiveFocus();
                    root.dragStarted(centroid.scenePosition.x,
                        centroid.scenePosition.y);
                } else if (root.isDragging) {
                    // Commit the drop while this delegate is still marked as
                    // dragged. Its visual slot can then settle without a
                    // one-frame jump caused by the model move.
                    root.dragEnded();
                    root.isDragging = false;
                    root.dragOffsetX = 0;
                    root.dragOffsetY = 0;
                }
            }

            onCentroidChanged: {
                if (active) {
                    root.dragMoved(centroid.scenePosition.x,
                        centroid.scenePosition.y);
                }
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

        QQC2.ToolTip.visible: iconHover.hovered && root.appName.length > 0 && !root.isDragging && (!root.isRunning || !root.windowsList || root.windowsList.length === 0)
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

    function setPreviewOpen(open) {
        var requested = Boolean(open && previewAvailable
            && hasWindowPreviews && !isDragging);
        if (previewOpen === requested && previewWindow.visible === requested) {
            if (!requested) {
                previewDataRequested = false;
            }
            return;
        }
        previewOpen = requested;
        if (requested) {
            previewDataRequested = true;
            positionPreviewWindow();
            previewWindow.visible = true;
            schedulePreviewPosition();
        } else {
            previewWindow.visible = false;
            previewDataRequested = false;
        }
        previewVisibilityChanged(requested);
    }

    function schedulePreviewPosition() {
        if (!previewWindow.visible || previewPositionPending) {
            return;
        }
        previewPositionPending = true;
        Qt.callLater(runScheduledPreviewPosition);
    }

    function runScheduledPreviewPosition() {
        previewPositionPending = false;
        if (previewWindow.visible) {
            positionPreviewWindow();
        }
    }

    function positionPreviewWindow() {
        var spacing = Kirigami.Units.smallSpacing;
        var targetScreen = previewWindow.screen;
        if (!targetScreen) {
            return;
        }

        var owningWindow = iconContainer.Window.window;
        if (!owningWindow || !owningWindow.contentItem) {
            return;
        }
        var localIconTopLeft = iconContainer.mapToItem(
            owningWindow.contentItem, 0, 0);
        var screenLeft = targetScreen.virtualX;
        var screenTop = targetScreen.virtualY;
        var screenRight = screenLeft + targetScreen.width;
        var screenBottom = screenTop + targetScreen.height;
        var windowLeft;
        var windowTop;
        if (root.isVertical) {
            windowLeft = root.location === PlasmaCore.Types.LeftEdge
                ? screenLeft + root.screenEdgeMargin
                : screenRight - root.screenEdgeMargin - owningWindow.width;
            windowTop = screenTop
                + (targetScreen.height - owningWindow.height) / 2;
        } else {
            windowLeft = screenLeft
                + (targetScreen.width - owningWindow.width) / 2;
            windowTop = root.location === PlasmaCore.Types.TopEdge
                ? screenTop + root.screenEdgeMargin
                : screenBottom - root.screenEdgeMargin - owningWindow.height;
        }
        var iconTopLeft = Qt.point(
            windowLeft + localIconTopLeft.x,
            windowTop + localIconTopLeft.y);

        previewWindow.placementLeft = 0;
        previewWindow.placementTop = 0;
        previewWindow.placementRight = 0;
        previewWindow.placementBottom = 0;

        if (root.isVertical) {
            previewWindow.placementTop = Math.max(spacing,
                Math.min(targetScreen.height - previewWindow.height - spacing,
                    iconTopLeft.y - screenTop
                        + (iconContainer.height - previewWindow.height) / 2));
            if (root.location === PlasmaCore.Types.LeftEdge) {
                previewWindow.placementLeft = iconTopLeft.x - screenLeft
                    + iconContainer.width + spacing;
            } else {
                previewWindow.placementRight = screenRight - iconTopLeft.x
                    + spacing;
            }
        } else {
            previewWindow.placementLeft = Math.max(spacing,
                Math.min(targetScreen.width - previewWindow.width - spacing,
                    iconTopLeft.x - screenLeft
                        + (iconContainer.width - previewWindow.width) / 2));
            if (root.location === PlasmaCore.Types.TopEdge) {
                previewWindow.placementTop = iconTopLeft.y - screenTop
                    + iconContainer.height + spacing;
            } else {
                previewWindow.placementBottom = screenBottom - iconTopLeft.y
                    + spacing;
            }
        }
    }

    function schedulePreviewClose() {
        if (previewOpen) {
            previewCloseTimer.restart();
        } else {
            previewDataRequested = false;
        }
    }
}
