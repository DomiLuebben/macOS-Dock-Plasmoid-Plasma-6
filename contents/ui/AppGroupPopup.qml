pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.layershell as LayerShell
import org.kde.plasma.core as PlasmaCore
import "effects" as DockEffects

Window {
    id: root

    property string groupId: ""
    property string groupName: ""
    property var members: []
    property Item visualParent: null
    property int location: PlasmaCore.Types.BottomEdge
    property real screenEdgeMargin: 0
    property real surfaceOpacity: 0.84
    property bool useThemeColor: true
    property color customColor: "#20242b"
    property real requestedRadius: 18
    property real borderOpacity: 0.22
    property real shadowOpacity: 0.42
    property bool showHighlight: true
    property bool blurEnabled: true
    readonly property int listViewMode: 0
    readonly property int gridViewMode: 1
    property int viewMode: gridViewMode

    readonly property bool isVertical:
        location === PlasmaCore.Types.LeftEdge
        || location === PlasmaCore.Types.RightEdge
    readonly property bool hovered: popupHover.hovered
    readonly property bool gridViewActive: viewMode === gridViewMode
    readonly property int memberCount: members ? members.length : 0
    readonly property int visibleMemberCount:
        Math.min(7, memberCount)
    readonly property int gridColumnCount: 3
    readonly property int visibleGridRowCount: Math.min(3,
        Math.ceil(memberCount / gridColumnCount))
    property string expandedLauncher: ""
    readonly property var expandedMember: {
        var source = members || [];
        for (var index = 0; index < source.length; ++index) {
            if (String(source[index].launcher || "")
                    === expandedLauncher) {
                return source[index];
            }
        }
        return null;
    }
    readonly property var expandedWindows:
        expandedMember ? expandedMember.windows || [] : []
    readonly property int expandedWindowCount: expandedWindows.length
    readonly property real maximumPopupHeight: screen
        ? Math.max(180, screen.height - 48) : 500
    readonly property real preferredListHeight:
        74 + visibleMemberCount * 52
            + Math.max(0, visibleMemberCount - 1) * 3
            + Math.min(6, expandedWindowCount) * 39
    readonly property real preferredGridHeight:
        82 + Math.max(1, visibleGridRowCount) * 98
            + (expandedWindowCount > 1
                ? Math.min(4, expandedWindowCount) * 39 + 10 : 0)
    property real openProgress: 0
    property bool positionPending: false
    property real placementLeft: 0
    property real placementTop: 0
    property real placementRight: 0
    property real placementBottom: 0

    signal memberActivated(string launcherUrl)
    signal memberNewInstanceRequested(string launcherUrl)
    signal memberWindowActivated(var modelIndex)
    signal memberWindowClosed(var modelIndex)
    signal memberRemoved(string launcherUrl)
    signal groupNameRequested(string name)
    signal ungroupRequested()

    component WindowChoiceRow: Item {
        id: windowChoice

        required property var windowData
        property var appIcon: "window"
        property string appName: ""

        signal activateRequested(var modelIndex)
        signal closeRequested(var modelIndex)

        width: parent ? parent.width : 0
        height: 36
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: String(
            windowData.title || appName || i18n("Application"))
        Accessible.description: i18n("Activate")
        Accessible.onPressAction:
            windowChoice.activateRequested(windowData.modelIndex)

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 42
            radius: 9
            color: windowChoiceHover.hovered
                    || Boolean(windowChoice.windowData.isActive)
                ? Kirigami.Theme.highlightColor
                : Kirigami.Theme.alternateBackgroundColor
            opacity: windowChoiceHover.hovered ? 0.22
                : (Boolean(windowChoice.windowData.isActive)
                    ? 0.16 : 0.38)
        }

        Kirigami.Icon {
            anchors.left: parent.left
            anchors.leftMargin: 50
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20
            source: Boolean(windowChoice.windowData.isMinimized)
                ? "window-minimize" : windowChoice.appIcon
        }

        QQC2.Label {
            anchors.left: parent.left
            anchors.leftMargin: 76
            anchors.right: closeWindowButton.left
            anchors.rightMargin: Kirigami.Units.smallSpacing
            anchors.verticalCenter: parent.verticalCenter
            text: String(windowChoice.windowData.title
                || windowChoice.appName || i18n("Application"))
            font.pixelSize: 12
            elide: Text.ElideRight
            opacity: Boolean(windowChoice.windowData.isMinimized)
                ? 0.68 : 0.9
        }

        HoverHandler {
            id: windowChoiceHover
            cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
            anchors.left: parent.left
            anchors.right: closeWindowButton.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: windowChoice.activateRequested(
                windowChoice.windowData.modelIndex)
        }

        QQC2.ToolButton {
            id: closeWindowButton

            anchors.right: parent.right
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 30
            opacity: windowChoiceHover.hovered || activeFocus ? 1 : 0
            text: i18n("Close")
            icon.name: "window-close"
            display: QQC2.AbstractButton.IconOnly
            onClicked: windowChoice.closeRequested(
                windowChoice.windowData.modelIndex)

            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }

            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.text: text
        }
    }

    width: gridViewActive ? 352 : 306
    height: Math.max(gridViewActive ? 180 : 150,
        Math.min(maximumPopupHeight,
            gridViewActive ? preferredGridHeight : preferredListHeight))
    flags: Qt.FramelessWindowHint
    color: "transparent"
    visible: false

    LayerShell.Window.scope: "macosdock-app-group-popup"
    LayerShell.Window.anchors: {
        if (root.location === PlasmaCore.Types.LeftEdge) {
            return LayerShell.Window.AnchorLeft
                | LayerShell.Window.AnchorTop;
        }
        if (root.location === PlasmaCore.Types.RightEdge) {
            return LayerShell.Window.AnchorRight
                | LayerShell.Window.AnchorTop;
        }
        if (root.location === PlasmaCore.Types.TopEdge) {
            return LayerShell.Window.AnchorLeft
                | LayerShell.Window.AnchorTop;
        }
        return LayerShell.Window.AnchorLeft
            | LayerShell.Window.AnchorBottom;
    }
    LayerShell.Window.margins.left: placementLeft
    LayerShell.Window.margins.top: placementTop
    LayerShell.Window.margins.right: placementRight
    LayerShell.Window.margins.bottom: placementBottom
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.keyboardInteractivity:
        LayerShell.Window.KeyboardInteractivityOnDemand
    LayerShell.Window.activateOnShow: true
    LayerShell.Window.wantsToBeOnActiveScreen: true

    DockEffects.BlurRegion {
        window: root
        region: Qt.rect(0, 0, root.width, root.height)
        radius: popupBackground.radius
        enabled: root.blurEnabled
    }

    function showPopup() {
        closeAnimation.stop();
        expandedLauncher = "";
        positionPopup();
        openProgress = 0;
        visible = true;
        requestActivate();
        openAnimation.restart();
        schedulePositionPopup();
    }

    function hidePopup() {
        if (!visible) {
            return;
        }
        openAnimation.stop();
        closeAnimation.restart();
    }

    function finishClose() {
        visible = false;
        openProgress = 0;
        expandedLauncher = "";
    }

    function activateMember(member) {
        var windows = member && member.windows
            ? member.windows : [];
        var launcher = String(member ? member.launcher || "" : "");
        if (windows.length > 1) {
            expandedLauncher = expandedLauncher === launcher
                ? "" : launcher;
            return;
        }
        memberActivated(launcher);
    }

    function schedulePositionPopup() {
        if (!visible || positionPending) {
            return;
        }
        positionPending = true;
        Qt.callLater(runScheduledPositionPopup);
    }

    function runScheduledPositionPopup() {
        positionPending = false;
        if (visible) {
            positionPopup();
        }
    }

    function positionPopup() {
        if (!visualParent) {
            return;
        }
        var owningWindow = visualParent.Window.window;
        if (!owningWindow || !owningWindow.contentItem) {
            return;
        }
        var targetScreen = owningWindow.screen || root.screen;
        if (!targetScreen) {
            return;
        }

        var localTopLeft = visualParent.mapToItem(
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
        var itemTopLeft = Qt.point(windowLeft + localTopLeft.x,
            windowTop + localTopLeft.y);
        var spacing = Kirigami.Units.largeSpacing;

        placementLeft = 0;
        placementTop = 0;
        placementRight = 0;
        placementBottom = 0;

        if (root.isVertical) {
            placementTop = Math.max(spacing,
                Math.min(targetScreen.height - height - spacing,
                    itemTopLeft.y - screenTop
                        + (visualParent.height - height) / 2));
            if (root.location === PlasmaCore.Types.LeftEdge) {
                placementLeft = itemTopLeft.x - screenLeft
                    + visualParent.width + spacing;
            } else {
                placementRight = screenRight - itemTopLeft.x + spacing;
            }
        } else {
            placementLeft = Math.max(spacing,
                Math.min(targetScreen.width - width - spacing,
                    itemTopLeft.x - screenLeft
                        + (visualParent.width - width) / 2));
            if (root.location === PlasmaCore.Types.TopEdge) {
                placementTop = itemTopLeft.y - screenTop
                    + visualParent.height + spacing;
            } else {
                placementBottom = screenBottom - itemTopLeft.y + spacing;
            }
        }
    }

    onVisualParentChanged: if (visible) schedulePositionPopup()
    onWidthChanged: if (visible) schedulePositionPopup()
    onHeightChanged: if (visible) schedulePositionPopup()
    onScreenChanged: if (visible) schedulePositionPopup()
    onLocationChanged: if (visible) schedulePositionPopup()
    onScreenEdgeMarginChanged: if (visible) schedulePositionPopup()
    onViewModeChanged: expandedLauncher = ""
    onMembersChanged: {
        var keepExpanded = false;
        var source = members || [];
        for (var index = 0; index < source.length; ++index) {
            if (String(source[index].launcher || "")
                    === expandedLauncher
                    && (source[index].windows || []).length > 1) {
                keepExpanded = true;
                break;
            }
        }
        if (!keepExpanded) {
            expandedLauncher = "";
        }
    }
    onGroupNameChanged: {
        if (!nameField.activeFocus) {
            nameField.text = groupName;
        }
    }

    Connections {
        target: root.visualParent
        enabled: root.visible
        function onXChanged() { root.schedulePositionPopup(); }
        function onYChanged() { root.schedulePositionPopup(); }
        function onWidthChanged() { root.schedulePositionPopup(); }
        function onHeightChanged() { root.schedulePositionPopup(); }
    }

    Connections {
        target: root.visualParent ? root.visualParent.Window.window : null
        enabled: root.visible
        function onWidthChanged() { root.schedulePositionPopup(); }
        function onHeightChanged() { root.schedulePositionPopup(); }
        function onScreenChanged() { root.schedulePositionPopup(); }
    }

    Shortcut {
        sequences: [StandardKey.Cancel]
        enabled: root.visible
        onActivated: root.hidePopup()
    }

    ParallelAnimation {
        id: openAnimation

        // OutBack schiesst kurz ueber 1 hinaus. Da openProgress die Skalierung
        // treibt (0.72 + 0.28 * openProgress), entsteht daraus ein kleines
        // Aufpoppen statt eines blossen Einblendens. Die Deckkraft haengt an
        // derselben Groesse; Werte ueber 1 begrenzt Qt von selbst.
        NumberAnimation {
            target: root
            property: "openProgress"
            from: 0
            to: 1
            duration: 260
            easing.type: Easing.OutBack
            easing.overshoot: 1.35
        }
    }

    SequentialAnimation {
        id: closeAnimation

        NumberAnimation {
            target: root
            property: "openProgress"
            to: 0
            duration: 150
            easing.type: Easing.InCubic
        }
        ScriptAction { script: root.finishClose() }
    }

    Item {
        id: animatedPanel

        anchors.fill: parent
        opacity: root.openProgress
        scale: 0.72 + 0.28 * root.openProgress
        transformOrigin: {
            if (root.location === PlasmaCore.Types.LeftEdge) {
                return Item.Left;
            }
            if (root.location === PlasmaCore.Types.RightEdge) {
                return Item.Right;
            }
            if (root.location === PlasmaCore.Types.TopEdge) {
                return Item.Top;
            }
            return Item.Bottom;
        }

        DockBackground {
            id: popupBackground

            anchors.fill: parent
            surfaceOpacity: root.surfaceOpacity
            useThemeColor: root.useThemeColor
            customColor: root.customColor
            requestedRadius: root.requestedRadius
            borderOpacity: root.borderOpacity
            shadowOpacity: root.shadowOpacity
            showHighlight: root.showHighlight
        }

        HoverHandler {
            id: popupHover
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                spacing: Kirigami.Units.smallSpacing

                QQC2.TextField {
                    id: nameField

                    Layout.fillWidth: true
                    text: root.groupName
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    selectByMouse: true
                    Accessible.name: i18n("Group name")
                    onEditingFinished: {
                        var trimmedName = text.trim();
                        if (trimmedName.length > 0
                                && trimmedName !== root.groupName) {
                            root.groupNameRequested(trimmedName);
                        } else {
                            text = root.groupName;
                        }
                    }
                }

                QQC2.ToolButton {
                    text: i18n("Ungroup")
                    icon.name: "edit-delete"
                    display: QQC2.AbstractButton.IconOnly
                    onClicked: root.ungroupRequested()

                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: text
                }
            }

            ListView {
                id: memberList

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.viewMode === root.listViewMode
                clip: true
                spacing: 3
                model: root.visible && visible
                    ? root.members || [] : []
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true
                cacheBuffer: 104

                delegate: Item {
                    id: memberDelegate

                    required property int index
                    required property var modelData
                    readonly property string launcher:
                        String(modelData.launcher || "")
                    readonly property var memberWindows:
                        modelData.windows || []
                    readonly property bool hasWindowChoices:
                        memberWindows.length > 1
                    readonly property bool windowsExpanded:
                        hasWindowChoices
                        && root.expandedLauncher === launcher
                    readonly property real revealProgress: Math.max(0,
                        Math.min(1, (root.openProgress
                            - index * 0.035) / 0.76))

                    width: ListView.view.width
                    height: 52 + (windowsExpanded
                        ? memberWindows.length * 39 + 3 : 0)
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: String(
                        modelData.name || i18n("Application"))
                    Accessible.description: Boolean(modelData.running)
                        ? i18n("Running") : i18n("Launcher")
                    Accessible.onPressAction:
                        root.activateMember(modelData)
                    opacity: revealProgress
                    scale: 0.86 + revealProgress * 0.14

                    Behavior on height {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }

                    transform: Translate {
                        x: root.isVertical
                            ? (root.location === PlasmaCore.Types.LeftEdge
                                ? -10 : 10)
                                * (1 - memberDelegate.revealProgress)
                            : 0
                        y: root.isVertical ? 0
                            : (root.location === PlasmaCore.Types.TopEdge
                                ? -10 : 10)
                                * (1 - memberDelegate.revealProgress)
                    }

                    Item {
                        id: memberSummary

                        width: parent.width
                        height: 52

                        Rectangle {
                            anchors.fill: parent
                            radius: 11
                            color: memberHover.hovered
                                    || memberDelegate.windowsExpanded
                                ? Kirigami.Theme.highlightColor
                                : Kirigami.Theme.alternateBackgroundColor
                            opacity: memberHover.hovered ? 0.28
                                : (memberDelegate.windowsExpanded
                                    ? 0.2 : 0.54)

                            Behavior on opacity {
                                NumberAnimation { duration: 100 }
                            }
                        }

                        Kirigami.Icon {
                            anchors.left: parent.left
                            anchors.leftMargin: Kirigami.Units.smallSpacing
                            anchors.verticalCenter: parent.verticalCenter
                            width: 34
                            height: 34
                            source: memberDelegate.modelData.icon
                                || "application-x-executable"
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin:
                                Kirigami.Units.smallSpacing + 42
                            anchors.right: parent.right
                            anchors.rightMargin:
                                Kirigami.Units.smallSpacing + 36
                                + (memberDelegate.hasWindowChoices
                                    ? 31 : 0)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            QQC2.Label {
                                width: parent ? parent.width : 0
                                text: memberDelegate.modelData.name
                                    || i18n("Application")
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            QQC2.Label {
                                width: parent ? parent.width : 0
                                visible: Boolean(
                                    memberDelegate.modelData.running)
                                text: i18n("Running")
                                opacity: 0.62
                                font.pixelSize: 11
                            }
                        }

                        Rectangle {
                            id: windowCountBadge

                            visible: memberDelegate.hasWindowChoices
                            anchors.right: removeButton.left
                            anchors.rightMargin: 1
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 24
                            radius: 8
                            color: Kirigami.Theme.highlightColor
                            opacity: 0.72

                            QQC2.Label {
                                anchors.centerIn: parent
                                text: String(
                                    memberDelegate.memberWindows.length)
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color:
                                    Kirigami.Theme.highlightedTextColor
                            }
                        }

                        QQC2.ToolButton {
                            id: removeButton

                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 34
                            height: 34
                            opacity: memberHover.hovered
                                || activeFocus ? 1 : 0
                            text: i18n("Remove from Group")
                            icon.name: "list-remove"
                            display: QQC2.AbstractButton.IconOnly
                            onClicked: root.memberRemoved(
                                memberDelegate.launcher)

                            Behavior on opacity {
                                NumberAnimation { duration: 100 }
                            }

                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.text: text
                        }

                        HoverHandler {
                            id: memberHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        MouseArea {
                            anchors.left: parent.left
                            anchors.right: removeButton.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            acceptedButtons:
                                Qt.LeftButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.MiddleButton) {
                                    root.memberNewInstanceRequested(
                                        memberDelegate.launcher);
                                } else {
                                    root.activateMember(
                                        memberDelegate.modelData);
                                }
                            }
                        }
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: memberSummary.bottom
                        anchors.topMargin: 3
                        spacing: 3
                        visible: memberDelegate.windowsExpanded
                        opacity: visible ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation { duration: 130 }
                        }

                        Repeater {
                            model: memberDelegate.memberWindows

                            delegate: WindowChoiceRow {
                                required property var modelData

                                windowData: modelData
                                appIcon: memberDelegate.modelData.icon
                                    || "window"
                                appName: String(
                                    memberDelegate.modelData.name || "")
                                onActivateRequested: (modelIndex) =>
                                    root.memberWindowActivated(modelIndex)
                                onCloseRequested: (modelIndex) =>
                                    root.memberWindowClosed(modelIndex)
                            }
                        }
                    }
                }

                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
            }

            GridView {
                id: memberGrid

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.gridViewActive
                clip: true
                cellWidth: width / root.gridColumnCount
                cellHeight: 98
                model: root.visible && visible
                    ? root.members || [] : []
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true
                cacheBuffer: 196

                delegate: Item {
                    id: gridMember

                    required property int index
                    required property var modelData
                    readonly property string launcher:
                        String(modelData.launcher || "")
                    readonly property var memberWindows:
                        modelData.windows || []
                    readonly property bool windowsExpanded:
                        memberWindows.length > 1
                        && root.expandedLauncher === launcher
                    readonly property real revealProgress: Math.max(0,
                        Math.min(1, (root.openProgress
                            - index * 0.045) / 0.72))

                    width: GridView.view.cellWidth
                    height: GridView.view.cellHeight
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: String(
                        modelData.name || i18n("Application"))
                    Accessible.description: Boolean(modelData.running)
                        ? i18n("Running") : i18n("Launcher")
                    Accessible.onPressAction:
                        root.activateMember(modelData)
                    opacity: revealProgress
                    scale: 0.78 + revealProgress * 0.22

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 16
                        color: gridMemberHover.hovered
                                || gridMember.windowsExpanded
                            ? Kirigami.Theme.highlightColor
                            : Kirigami.Theme.alternateBackgroundColor
                        opacity: gridMemberHover.hovered ? 0.28
                            : (gridMember.windowsExpanded ? 0.2 : 0.46)

                        Behavior on opacity {
                            NumberAnimation { duration: 100 }
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        anchors.topMargin: 8
                        anchors.bottomMargin: 6
                        spacing: 3

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 50

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 46
                                height: 46
                                source: gridMember.modelData.icon
                                    || "application-x-executable"
                            }

                            Rectangle {
                                visible: Boolean(
                                    gridMember.modelData.running)
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                width: 8
                                height: 8
                                radius: 4
                                color: Kirigami.Theme.highlightColor
                                border.color: popupBackground.effectiveColor
                                border.width: 1
                            }
                        }

                        QQC2.Label {
                            Layout.fillWidth: true
                            text: gridMember.modelData.name
                                || i18n("Application")
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        visible: gridMember.memberWindows.length > 1
                        anchors.left: parent.left
                        anchors.leftMargin: 7
                        anchors.top: parent.top
                        anchors.topMargin: 7
                        width: 24
                        height: 20
                        radius: 7
                        color: Kirigami.Theme.highlightColor
                        opacity: 0.82

                        QQC2.Label {
                            anchors.centerIn: parent
                            text: String(
                                gridMember.memberWindows.length)
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: Kirigami.Theme.highlightedTextColor
                        }
                    }

                    QQC2.ToolButton {
                        id: removeGridMemberButton

                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.top: parent.top
                        anchors.topMargin: 4
                        width: 28
                        height: 28
                        z: 2
                        opacity: gridMemberHover.hovered
                            || activeFocus ? 1 : 0
                        text: i18n("Remove from Group")
                        icon.name: "list-remove"
                        display: QQC2.AbstractButton.IconOnly
                        onClicked: root.memberRemoved(
                            gridMember.launcher)

                        Behavior on opacity {
                            NumberAnimation { duration: 100 }
                        }

                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.text: text
                    }

                    HoverHandler {
                        id: gridMemberHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons:
                            Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.MiddleButton) {
                                root.memberNewInstanceRequested(
                                    gridMember.launcher);
                            } else {
                                root.activateMember(
                                    gridMember.modelData);
                            }
                        }
                    }
                }

                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
            }

            Rectangle {
                id: gridWindowChoices

                Layout.fillWidth: true
                Layout.preferredHeight: visible
                    ? Math.min(4, root.expandedWindowCount) * 39 + 8 : 0
                visible: root.gridViewActive
                    && root.expandedWindowCount > 1
                radius: 11
                color: Kirigami.Theme.alternateBackgroundColor
                opacity: 0.78
                clip: true

                ListView {
                    anchors.fill: parent
                    anchors.margins: 4
                    model: gridWindowChoices.visible
                        ? root.expandedWindows : []
                    spacing: 3
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    reuseItems: true
                    cacheBuffer: 156

                    delegate: WindowChoiceRow {
                        required property var modelData

                        windowData: modelData
                        appIcon: root.expandedMember
                            ? root.expandedMember.icon || "window"
                            : "window"
                        appName: root.expandedMember
                            ? String(root.expandedMember.name || "") : ""
                        onActivateRequested: (modelIndex) =>
                            root.memberWindowActivated(modelIndex)
                        onCloseRequested: (modelIndex) =>
                            root.memberWindowClosed(modelIndex)
                    }

                    QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
                }
            }
        }
    }
}
