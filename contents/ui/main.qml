pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.layershell as LayerShell
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager
import "effects" as DockEffects

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.constraintHints: Plasmoid.CanFillArea

    preferredRepresentation: fullRepresentation
    activationTogglesExpanded: false

    readonly property real maxScale: boundedNumber(
        Plasmoid.configuration.maxScale, 1.45, 1.0, 2.0)
    readonly property real zoomRadius: boundedNumber(
        Plasmoid.configuration.zoomRadius, 70, 30, 200)
    readonly property real configuredIconSize: boundedNumber(
        Plasmoid.configuration.iconSize, 44, 24, 96)
    readonly property int dockLocation: Plasmoid.formFactor
        === PlasmaCore.Types.Planar
        ? PlasmaCore.Types.BottomEdge : Plasmoid.location
    readonly property bool isVertical:
        dockLocation === PlasmaCore.Types.LeftEdge
        || dockLocation === PlasmaCore.Types.RightEdge
    readonly property real itemSpacing: 4
    readonly property real windowPadding: 10
    readonly property real mainMargin: boundedNumber(
        Plasmoid.configuration.dockMargin, 16, 4, 40)
    readonly property real crossMargin: boundedNumber(
        Plasmoid.configuration.dockCrossMargin, 5, 0, 20)
    readonly property real panelEdgeMargin: boundedNumber(
        Plasmoid.configuration.screenEdgeMargin, 8, 0, 32)
    readonly property real backgroundOpacity: boundedNumber(
        Plasmoid.configuration.backgroundOpacity, 0.55, 0.15, 1.0)
    readonly property bool useThemeBackground:
        Plasmoid.configuration.useThemeBackground === undefined
            ? true : Boolean(Plasmoid.configuration.useThemeBackground)
    readonly property color customBackgroundColor:
        Plasmoid.configuration.customBackgroundColor || "#20242b"
    readonly property real cornerRadius: boundedNumber(
        Plasmoid.configuration.cornerRadius, 12, 0, 48)
    readonly property real borderOpacity: boundedNumber(
        Plasmoid.configuration.borderOpacity, 0.22, 0, 0.5)
    readonly property real shadowOpacity: boundedNumber(
        Plasmoid.configuration.shadowOpacity, 0.42, 0, 0.7)
    readonly property bool showHighlight:
        Plasmoid.configuration.showHighlight === undefined
            ? true : Boolean(Plasmoid.configuration.showHighlight)
    readonly property bool enableBlur:
        Plasmoid.configuration.enableBlur === undefined
            ? true : Boolean(Plasmoid.configuration.enableBlur)
    readonly property bool hideOnMaximized:
        Plasmoid.configuration.hideOnMaximized === undefined
            ? true : Boolean(Plasmoid.configuration.hideOnMaximized)
    readonly property int launchAnimation: Math.round(boundedNumber(
        Plasmoid.configuration.launchAnimation, 1, 0, 1))
    readonly property real indicatorSize: 3
    readonly property real indicatorGap: 2
    readonly property real indicatorSpace: indicatorSize + indicatorGap
    readonly property real baseIconSize: configuredIconSize
    readonly property real baseSurfaceCrossLength:
        baseIconSize + indicatorSpace + 2 * crossMargin
    readonly property real baseSurfaceMainLength: preferredMainLength
    readonly property real maximumIconSize: baseIconSize * maxScale
    readonly property int taskCount: tasksModel.count
    readonly property real restMainLength: taskCount > 0
        ? taskCount * baseIconSize + (taskCount - 1) * itemSpacing : 0
    readonly property real maximumExpansion: maximumWaveExpansion(taskCount)
    readonly property real preferredMainLength: taskCount > 0
        ? restMainLength + 2 * mainMargin : Kirigami.Units.gridUnit
    readonly property real maximumOverlayMainLength: taskCount > 0
        ? restMainLength + maximumExpansion + 2 * mainMargin
        : Kirigami.Units.gridUnit
    readonly property real overlayCrossLength:
        maximumIconSize + indicatorSpace + 2 * crossMargin
            + 2 * windowPadding
    readonly property real overlayWindowWidth: isVertical
        ? overlayCrossLength : maximumOverlayMainLength + 2 * windowPadding
    readonly property real overlayWindowHeight: isVertical
        ? maximumOverlayMainLength + 2 * windowPadding : overlayCrossLength
    readonly property real baseWindowWidth: isVertical
        ? baseSurfaceCrossLength : baseSurfaceMainLength
    readonly property real baseWindowHeight: isVertical
        ? baseSurfaceMainLength : baseSurfaceCrossLength
    readonly property real overlayWindowMainLength: isVertical
        ? overlayWindowHeight : overlayWindowWidth
    readonly property real baseWindowMainLength: isVertical
        ? baseWindowHeight : baseWindowWidth

    Layout.minimumWidth: 1
    Layout.minimumHeight: 1
    Layout.preferredWidth: 1
    Layout.preferredHeight: 1

    implicitWidth: 1
    implicitHeight: 1

    property bool taskModelReady: false
    property bool overlayOpen: false
    readonly property bool dockAvailable: taskCount > 0
        && representationItem !== null
    readonly property bool maximizedWindowPresent:
        maximizedWindowsModel.count > 0
    readonly property bool autoHideRequired:
        hideOnMaximized && maximizedWindowPresent
    property bool revealedForMaximized: false
    readonly property bool dockRequestedVisible: dockAvailable
        && (!autoHideRequired || revealedForMaximized
            || baseHovered || overlayHovered
            || openMenuCount > 0)
    property real dockRevealProgress: dockRequestedVisible ? 1.0 : 0.0
    readonly property bool dockWindowVisible: dockAvailable
        && (dockRequestedVisible || dockRevealProgress > 0.001)
    readonly property bool overlayVisible: overlayOpen && dockWindowVisible
    property Item representationItem: null
    property bool baseHovered: false
    property bool overlayHovered: false
    property bool edgeHovered: false
    property int openMenuCount: 0
    property var openContextMenu: null
    property var adjustedContainment: null
    property int previousContainmentBackgroundHints: 0
    property int previousContainmentUserBackgroundHints: 0
    property bool containmentBackgroundAdjusted: false
    property real lastPointerMain: isVertical
        ? overlayWindowHeight / 2 : overlayWindowWidth / 2

    Behavior on dockRevealProgress {
        NumberAnimation {
            duration: root.dockRequestedVisible ? 240 : 300
            easing.type: root.dockRequestedVisible
                ? Easing.OutCubic : Easing.InCubic
        }
    }

    DockEffects.BlurRegion {
        window: baseWindow
        region: Qt.rect(baseSurface.x
                + root.dockSlideX(baseWindow.width),
            baseSurface.y + root.dockSlideY(baseWindow.height),
            baseSurface.width, baseSurface.height)
        radius: baseSurface.radius
        enabled: root.enableBlur
    }

    DockEffects.BlurRegion {
        window: overlayWindow
        region: Qt.rect(overlayBackgroundSurface.x
                + root.dockSlideX(overlayWindow.width),
            overlayBackgroundSurface.y
                + root.dockSlideY(overlayWindow.height),
            overlayBackgroundSurface.width,
            overlayBackgroundSurface.height)
        radius: overlayBackgroundSurface.radius
        enabled: root.enableBlur
    }

    DockEffects.WindowActions {
        id: windowActions
    }

    function boundedNumber(value, fallback, minimum, maximum) {
        var number = Number(value);
        if (!Number.isFinite(number)) {
            number = fallback;
        }
        return Math.min(maximum, Math.max(minimum, number));
    }

    function makePanelTransparent() {
        var containment = Plasmoid.containment;
        if (containment
                && Plasmoid.formFactor !== PlasmaCore.Types.Planar) {
            if (!containmentBackgroundAdjusted) {
                adjustedContainment = containment;
                previousContainmentBackgroundHints = containment.backgroundHints;
                previousContainmentUserBackgroundHints =
                    containment.userBackgroundHints;
                containmentBackgroundAdjusted = true;
            }
            containment.backgroundHints = PlasmaCore.Types.NoBackground;
            containment.userBackgroundHints = PlasmaCore.Types.NoBackground;
        }
    }

    function restorePanelBackground() {
        if (!containmentBackgroundAdjusted || !adjustedContainment) {
            return;
        }
        if (adjustedContainment.backgroundHints
                === PlasmaCore.Types.NoBackground) {
            adjustedContainment.backgroundHints =
                previousContainmentBackgroundHints;
        }
        if (adjustedContainment.userBackgroundHints
                === PlasmaCore.Types.NoBackground) {
            adjustedContainment.userBackgroundHints =
                previousContainmentUserBackgroundHints;
        }
        adjustedContainment = null;
        containmentBackgroundAdjusted = false;
    }

    Component.onCompleted: makePanelTransparent()
    Component.onDestruction: restorePanelBackground()

    function dockSlideX(windowWidth) {
        var hiddenFraction = 1.0 - dockRevealProgress;
        if (dockLocation === PlasmaCore.Types.LeftEdge) {
            return -windowWidth * hiddenFraction;
        }
        if (dockLocation === PlasmaCore.Types.RightEdge) {
            return windowWidth * hiddenFraction;
        }
        return 0;
    }

    function dockSlideY(windowHeight) {
        var hiddenFraction = 1.0 - dockRevealProgress;
        if (dockLocation === PlasmaCore.Types.TopEdge) {
            return -windowHeight * hiddenFraction;
        }
        if (dockLocation === PlasmaCore.Types.BottomEdge) {
            return windowHeight * hiddenFraction;
        }
        return 0;
    }

    function waveScale(distance, maximum) {
        if (distance >= zoomRadius || maximum <= 1.0) {
            return 1.0;
        }

        var influence = 0.5 * (1.0 + Math.cos(Math.PI * distance / zoomRadius));
        return 1.0 + (maximum - 1.0) * influence;
    }

    function scaleForIndex(index, pointer, active, mainLength, maximum, iconSize) {
        if (!active || index < 0 || index >= taskCount) {
            return 1.0;
        }

        var restLength = taskCount * iconSize
            + Math.max(0, taskCount - 1) * itemSpacing;
        var firstCenter = (mainLength - restLength) / 2 + iconSize / 2;
        var center = firstCenter + index * (iconSize + itemSpacing);
        return waveScale(Math.abs(pointer - center), maximum);
    }

    function maximumWaveExpansion(count) {
        if (count <= 0 || maxScale <= 1.0) {
            return 0;
        }

        var slot = baseIconSize + itemSpacing;
        var sampleCount = Math.max(1, (count - 1) * 8);
        var largest = 0;

        for (var sample = 0; sample <= sampleCount; ++sample) {
            var pointer = baseIconSize / 2 + sample * slot / 8;
            var expansion = 0;
            for (var index = 0; index < count; ++index) {
                var center = baseIconSize / 2 + index * slot;
                expansion += baseIconSize
                    * (waveScale(Math.abs(pointer - center), maxScale) - 1.0);
            }
            largest = Math.max(largest, expansion);
        }
        return largest;
    }

    function scheduleOverlayClose() {
        overlayCloseTimer.restart();
    }

    function revealDock() {
        dockHideTimer.stop();
        revealedForMaximized = true;
    }

    function scheduleDockHide() {
        if (autoHideRequired && !baseHovered && !overlayHovered
                && !edgeHovered && openMenuCount === 0) {
            dockHideTimer.restart();
        }
    }

    function configureContextMenu(menu) {
        // Qt 6.8+ can place the menu in a real transient window. On Wayland,
        // the compositor can then dismiss it for clicks outside the Dock's
        // own layer-shell surfaces. Keep the item-popup fallback for older Qt.
        if (menu && menu["popupType"] !== undefined
                && QQC2.Popup["Window"] !== undefined) {
            menu["popupType"] = QQC2.Popup["Window"];
        }
    }

    function menuOpened(menu) {
        if (openContextMenu && openContextMenu !== menu) {
            openContextMenu.close();
        }
        openContextMenu = menu;
        ++openMenuCount;
        overlayCloseTimer.stop();
        revealDock();
        overlayOpen = true;
    }

    function menuClosed(menu) {
        if (openContextMenu === menu) {
            openContextMenu = null;
        }
        openMenuCount = Math.max(0, openMenuCount - 1);
        scheduleOverlayClose();
        scheduleDockHide();
    }

    function closeOpenContextMenu() {
        if (openContextMenu) {
            openContextMenu.close();
        }
    }

    function sameStringList(first, second) {
        var firstLength = first ? first.length : 0;
        var secondLength = second ? second.length : 0;
        if (firstLength !== secondLength) {
            return false;
        }
        for (var index = 0; index < firstLength; ++index) {
            if (String(first[index]) !== String(second[index])) {
                return false;
            }
        }
        return true;
    }

    function modelIndex(row) {
        return tasksModel.makeModelIndex(row);
    }

    function taskRole(index, role) {
        return tasksModel.data(index, role);
    }

    function isGroup(row) {
        return Boolean(taskRole(modelIndex(row),
            TaskManager.AbstractTasksModel.IsGroupParent));
    }

    function preferredWindowIndex(row) {
        var parentIndex = modelIndex(row);
        if (!isGroup(row)) {
            return parentIndex;
        }

        var childCount = tasksModel.rowCount(parentIndex);
        var preferredIndex = childCount > 0
            ? tasksModel.makeModelIndex(row, 0) : parentIndex;
        var latestActivation = -1;
        for (var child = 0; child < childCount; ++child) {
            var childIndex = tasksModel.makeModelIndex(row, child);
            if (Boolean(taskRole(childIndex,
                    TaskManager.AbstractTasksModel.IsActive))) {
                return childIndex;
            }
            var activated = taskRole(childIndex,
                TaskManager.AbstractTasksModel.LastActivated);
            var timestamp = activated && activated.getTime
                ? activated.getTime() : Date.parse(String(activated || ""));
            if (Number.isFinite(timestamp) && timestamp > latestActivation) {
                latestActivation = timestamp;
                preferredIndex = childIndex;
            }
        }
        return preferredIndex;
    }

    function activateTask(row, launcher) {
        var index = modelIndex(row);
        if (launcher) {
            tasksModel.requestNewInstance(index);
            return;
        }

        var windowIndex = preferredWindowIndex(row);
        var active = Boolean(taskRole(windowIndex,
            TaskManager.AbstractTasksModel.IsActive));
        var minimized = Boolean(taskRole(windowIndex,
            TaskManager.AbstractTasksModel.IsMinimized));
        if (active && !minimized) {
            tasksModel.requestToggleMinimized(windowIndex);
            return;
        }
        tasksModel.requestActivate(windowIndex);
    }

    function openTask(row, launcher) {
        var index = modelIndex(row);
        if (launcher) {
            tasksModel.requestNewInstance(index);
        } else {
            tasksModel.requestActivate(preferredWindowIndex(row));
        }
    }

    function allTaskWindowsHaveState(row, stateRole, parentState,
            modelChildCount) {
        var parentIndex = modelIndex(row);
        if (!isGroup(row)) {
            return Boolean(parentState);
        }

        // modelChildCount is passed so the binding is reevaluated whenever a
        // grouped task gains or loses a child window.
        var childCount = tasksModel.rowCount(parentIndex);
        if (childCount === 0) {
            return Boolean(parentState);
        }
        for (var child = 0; child < childCount; ++child) {
            if (!Boolean(taskRole(tasksModel.makeModelIndex(row, child),
                    stateRole))) {
                return false;
            }
        }
        return true;
    }

    function anyTaskWindowCan(row, capabilityRole, parentCapability,
            modelChildCount) {
        var parentIndex = modelIndex(row);
        if (!isGroup(row)) {
            return Boolean(parentCapability);
        }

        var childCount = tasksModel.rowCount(parentIndex);
        for (var child = 0; child < childCount; ++child) {
            if (Boolean(taskRole(tasksModel.makeModelIndex(row, child),
                    capabilityRole))) {
                return true;
            }
        }
        return Boolean(parentCapability) && childCount === 0;
    }

    function setTaskMinimized(row, minimized) {
        var parentIndex = modelIndex(row);
        if (!isGroup(row)) {
            if (Boolean(taskRole(parentIndex,
                    TaskManager.AbstractTasksModel.IsMinimizable))
                    && Boolean(taskRole(parentIndex,
                        TaskManager.AbstractTasksModel.IsMinimized)) !== minimized) {
                tasksModel.requestToggleMinimized(parentIndex);
            }
            return;
        }

        var childCount = tasksModel.rowCount(parentIndex);
        for (var child = 0; child < childCount; ++child) {
            var childIndex = tasksModel.makeModelIndex(row, child);
            if (Boolean(taskRole(childIndex,
                    TaskManager.AbstractTasksModel.IsMinimizable))
                    && Boolean(taskRole(childIndex,
                        TaskManager.AbstractTasksModel.IsMinimized)) !== minimized) {
                tasksModel.requestToggleMinimized(childIndex);
            }
        }
    }

    function setTaskMaximized(row, maximized) {
        var parentIndex = modelIndex(row);
        if (!isGroup(row)) {
            if (Boolean(taskRole(parentIndex,
                    TaskManager.AbstractTasksModel.IsMaximizable))
                    && Boolean(taskRole(parentIndex,
                        TaskManager.AbstractTasksModel.IsMaximized)) !== maximized) {
                tasksModel.requestToggleMaximized(parentIndex);
            }
            return;
        }

        var childCount = tasksModel.rowCount(parentIndex);
        for (var child = 0; child < childCount; ++child) {
            var childIndex = tasksModel.makeModelIndex(row, child);
            if (Boolean(taskRole(childIndex,
                    TaskManager.AbstractTasksModel.IsMaximizable))
                    && Boolean(taskRole(childIndex,
                        TaskManager.AbstractTasksModel.IsMaximized)) !== maximized) {
                tasksModel.requestToggleMaximized(childIndex);
            }
        }
    }

    function taskCanLaunchNewInstance(row, parentCapability,
            modelChildCount) {
        var parentIndex = modelIndex(row);
        if (Boolean(taskRole(parentIndex,
                TaskManager.AbstractTasksModel.IsLauncher))) {
            return true;
        }
        if (anyTaskWindowCan(row,
                TaskManager.AbstractTasksModel.CanLaunchNewInstance,
                parentCapability, modelChildCount)) {
            return true;
        }

        var launcher = taskRole(parentIndex,
            TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon)
            || taskRole(parentIndex,
                TaskManager.AbstractTasksModel.LauncherUrl);
        return String(launcher || "").length > 0;
    }

    function launchNewInstance(row) {
        var parentIndex = modelIndex(row);
        if (!isGroup(row)) {
            tasksModel.requestNewInstance(parentIndex);
            return;
        }

        var childCount = tasksModel.rowCount(parentIndex);
        for (var child = 0; child < childCount; ++child) {
            var childIndex = tasksModel.makeModelIndex(row, child);
            if (Boolean(taskRole(childIndex,
                    TaskManager.AbstractTasksModel.CanLaunchNewInstance))) {
                tasksModel.requestNewInstance(childIndex);
                return;
            }
        }
        if (childCount > 0) {
            tasksModel.requestNewInstance(tasksModel.makeModelIndex(row, 0));
        }
    }

    function closeTask(row) {
        var parentIndex = modelIndex(row);
        if (!isGroup(row)) {
            tasksModel.requestClose(parentIndex);
            return;
        }

        for (var child = tasksModel.rowCount(parentIndex) - 1;
                child >= 0; --child) {
            var childIndex = tasksModel.makeModelIndex(row, child);
            if (Boolean(taskRole(childIndex,
                    TaskManager.AbstractTasksModel.IsClosable))) {
                tasksModel.requestClose(childIndex);
            }
        }
    }

    function startInteractiveForceQuit() {
        windowActions.startInteractiveForceQuit();
    }

    function launcherUrl(task) {
        if (!task) {
            return "";
        }
        var value = task.LauncherUrlWithoutIcon || task.LauncherUrl || "";
        return String(value);
    }

    function launcherExists(task) {
        var url = launcherUrl(task);
        return url.length > 0 && tasksModel.launcherPosition(url) !== -1;
    }

    function toggleLauncher(task) {
        var url = launcherUrl(task);
        if (url.length === 0) {
            return;
        }

        if (tasksModel.launcherPosition(url) !== -1) {
            tasksModel.requestRemoveLauncher(url);
        } else {
            tasksModel.requestAddLauncher(url);
        }
    }

    function moveTask(row, offset) {
        var target = Math.max(0, Math.min(taskCount - 1, row + offset));
        if (target !== row && tasksModel.move(row, target)) {
            tasksModel.syncLaunchers();
        }
    }

    Timer {
        id: overlayCloseTimer

        interval: 250
        repeat: false
        onTriggered: {
            if (!root.baseHovered && !root.overlayHovered
                    && root.openMenuCount === 0) {
                root.overlayOpen = false;
            }
        }
    }

    Timer {
        id: dockHideTimer

        interval: 550
        repeat: false
        onTriggered: {
            if (root.autoHideRequired && !root.baseHovered
                    && !root.overlayHovered && !root.edgeHovered
                    && root.openMenuCount === 0) {
                root.overlayOpen = false;
                root.revealedForMaximized = false;
            }
        }
    }

    Connections {
        target: Qt.application

        function onStateChanged(state) {
            if (state !== Qt.ApplicationActive) {
                root.closeOpenContextMenu();
            }
        }
    }

    onAutoHideRequiredChanged: {
        dockHideTimer.stop();
        if (autoHideRequired) {
            scheduleDockHide();
        } else {
            revealedForMaximized = false;
        }
    }

    onTaskCountChanged: {
        if (taskCount === 0) {
            overlayOpen = false;
            revealedForMaximized = false;
        }
    }

    Connections {
        target: Plasmoid.configuration

        function onLaunchersChanged() {
            if (root.taskModelReady
                    && !root.sameStringList(tasksModel.launcherList,
                        Plasmoid.configuration.launchers)) {
                tasksModel.launcherList = Plasmoid.configuration.launchers || [];
            }
        }
    }

    TaskManager.TasksModel {
        id: tasksModel

        sortMode: TaskManager.TasksModel.SortManual
        groupMode: TaskManager.TasksModel.GroupApplications
        separateLaunchers: true
        launchInPlace: true
        hideActivatedLaunchers: true
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: false

        onLauncherListChanged: {
            if (root.taskModelReady
                    && !root.sameStringList(launcherList,
                        Plasmoid.configuration.launchers)) {
                Plasmoid.configuration.launchers = launcherList;
            }
        }

        Component.onCompleted: {
            launcherList = Plasmoid.configuration.launchers || [];
            root.taskModelReady = true;
        }
    }

    TaskManager.ActivityInfo {
        id: activityInfo
    }

    TaskManager.TasksModel {
        id: maximizedWindowsModel

        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByCurrentVirtualDesktop: true
        filterByActivity: true
        activity: activityInfo.currentActivity
        filterByScreen: true
        screenGeometry: baseWindow.screen
            ? Qt.rect(baseWindow.screen.virtualX,
                baseWindow.screen.virtualY,
                baseWindow.screen.width,
                baseWindow.screen.height)
            : Qt.rect(0, 0, 0, 0)
        filterMinimized: true
        filterNotMaximized: true
        filterHidden: true
    }

    component TaskDelegate: DockItem {
        id: taskDelegate

        required property int index
        required property var model
        property real displayScale: 1.0
        property real displayCrossExtent: root.baseIconSize

        readonly property bool launcherOnly: Boolean(model.IsLauncher)
        readonly property bool runningTask: !launcherOnly
            && (Boolean(model.IsWindow)
                || Boolean(model.IsStartup)
                || Boolean(model.IsGroupParent))
        readonly property bool groupParent: Boolean(model.IsGroupParent)
        readonly property bool pinned: Boolean(model.HasLauncher)
            || root.launcherExists(model)
        readonly property string launcherTarget: root.launcherUrl(model)
        readonly property bool canOpenNewInstance:
            root.taskCanLaunchNewInstance(index,
                Boolean(model.CanLaunchNewInstance), Number(model.ChildCount))
        readonly property bool allMinimized: runningTask
            && root.allTaskWindowsHaveState(index,
                TaskManager.AbstractTasksModel.IsMinimized,
                Boolean(model.IsMinimized), Number(model.ChildCount))
        readonly property bool allMaximized: runningTask
            && root.allTaskWindowsHaveState(index,
                TaskManager.AbstractTasksModel.IsMaximized,
                Boolean(model.IsMaximized), Number(model.ChildCount))
        readonly property bool canMinimize: runningTask
            && root.anyTaskWindowCan(index,
                TaskManager.AbstractTasksModel.IsMinimizable,
                Boolean(model.IsMinimizable), Number(model.ChildCount))
        readonly property bool canMaximize: runningTask
            && root.anyTaskWindowCan(index,
                TaskManager.AbstractTasksModel.IsMaximizable,
                Boolean(model.IsMaximizable), Number(model.ChildCount))
        readonly property bool canClose: runningTask
            && root.anyTaskWindowCan(index,
                TaskManager.AbstractTasksModel.IsClosable,
                Boolean(model.IsClosable), Number(model.ChildCount))

        appName: String(model.AppName || model.display || i18n("Application"))
        appIcon: model.decoration || "application-x-executable"
        baseSize: root.baseIconSize
        currentScale: displayScale
        crossIconExtent: displayCrossExtent
        isVertical: root.isVertical
        location: root.dockLocation
        isRunning: runningTask
        isActive: runningTask && Boolean(model.IsActive)
        isStarting: Boolean(model.IsStartup)
        launchAnimation: root.launchAnimation

        Behavior on currentScale {
            NumberAnimation {
                duration: 75
                easing.type: Easing.OutCubic
            }
        }

        onClicked: {
            triggerBounce();
            root.activateTask(index, launcherOnly);
        }

        onNewInstanceRequested: {
            triggerBounce();
            root.launchNewInstance(index);
        }

        onContextMenuRequested: taskMenu.popup()

        QQC2.Menu {
            id: taskMenu

            property bool countedAsOpen: false
            closePolicy: QQC2.Popup.CloseOnEscape
                | QQC2.Popup.CloseOnPressOutside
                | QQC2.Popup.CloseOnReleaseOutside
                | QQC2.Popup.CloseOnPressOutsideParent
                | QQC2.Popup.CloseOnReleaseOutsideParent

            Component.onCompleted: root.configureContextMenu(taskMenu)

            onOpened: {
                if (!countedAsOpen) {
                    countedAsOpen = true;
                    root.menuOpened(taskMenu);
                }
            }
            onClosed: {
                if (countedAsOpen) {
                    countedAsOpen = false;
                    root.menuClosed(taskMenu);
                }
            }
            Component.onDestruction: {
                if (countedAsOpen) {
                    root.menuClosed(taskMenu);
                }
            }

            QQC2.MenuItem {
                text: taskDelegate.runningTask
                    ? i18n("Activate") : i18n("Open")
                icon.name: taskDelegate.runningTask ? "window" : "system-run"
                onTriggered: root.openTask(taskDelegate.index,
                    taskDelegate.launcherOnly)
            }

            QQC2.MenuItem {
                text: i18n("Open New Window")
                icon.name: "window-new"
                visible: taskDelegate.canOpenNewInstance
                onTriggered: root.launchNewInstance(taskDelegate.index)
            }

            QQC2.MenuSeparator {}

            QQC2.MenuItem {
                text: taskDelegate.pinned
                    ? i18n("Unpin from Dock") : i18n("Keep in Dock")
                icon.name: taskDelegate.pinned ? "list-remove" : "bookmark-new"
                enabled: taskDelegate.launcherTarget.length > 0
                onTriggered: root.toggleLauncher(taskDelegate.model)
            }

            QQC2.MenuItem {
                text: root.isVertical ? i18n("Move Up") : i18n("Move Left")
                icon.name: root.isVertical ? "go-up" : "go-previous"
                visible: taskDelegate.pinned
                enabled: taskDelegate.index > 0
                onTriggered: root.moveTask(taskDelegate.index, -1)
            }

            QQC2.MenuItem {
                text: root.isVertical ? i18n("Move Down") : i18n("Move Right")
                icon.name: root.isVertical ? "go-down" : "go-next"
                visible: taskDelegate.pinned
                enabled: taskDelegate.index < root.taskCount - 1
                onTriggered: root.moveTask(taskDelegate.index, 1)
            }

            QQC2.MenuSeparator {
                visible: taskDelegate.runningTask
            }

            QQC2.MenuItem {
                text: taskDelegate.allMinimized
                    ? (taskDelegate.groupParent
                        ? i18n("Restore All") : i18n("Restore"))
                    : (taskDelegate.groupParent
                        ? i18n("Minimize All") : i18n("Minimize"))
                icon.name: taskDelegate.allMinimized
                    ? "window-restore" : "window-minimize"
                visible: taskDelegate.runningTask
                enabled: taskDelegate.canMinimize
                onTriggered: root.setTaskMinimized(taskDelegate.index,
                    !taskDelegate.allMinimized)
            }

            QQC2.MenuItem {
                text: taskDelegate.allMaximized
                    ? (taskDelegate.groupParent
                        ? i18n("Restore All") : i18n("Restore"))
                    : (taskDelegate.groupParent
                        ? i18n("Maximize All") : i18n("Maximize"))
                icon.name: taskDelegate.allMaximized
                    ? "window-restore" : "window-maximize"
                visible: taskDelegate.runningTask
                enabled: taskDelegate.canMaximize
                onTriggered: root.setTaskMaximized(taskDelegate.index,
                    !taskDelegate.allMaximized)
            }

            QQC2.MenuItem {
                text: taskDelegate.groupParent
                    ? i18n("Close All Windows") : i18n("Close")
                icon.name: "window-close"
                visible: taskDelegate.runningTask
                enabled: taskDelegate.canClose
                onTriggered: root.closeTask(taskDelegate.index)
            }

            QQC2.MenuSeparator {
                visible: taskDelegate.runningTask
            }

            QQC2.MenuItem {
                text: i18n("Force Quit Application…")
                icon.name: "process-stop"
                visible: taskDelegate.runningTask
                enabled: windowActions.interactiveForceQuitAvailable
                onTriggered: root.startInteractiveForceQuit()
            }
        }
    }

    fullRepresentation: Item {
        id: hostAnchor

        implicitWidth: 1
        implicitHeight: 1
        visible: false

        Component.onCompleted: root.representationItem = hostAnchor
        Component.onDestruction: {
            if (root.representationItem === hostAnchor) {
                root.representationItem = null;
            }
        }
    }

    Window {
        id: baseWindow

        objectName: "macOSDockBase"
        title: "macOS Dock"
        width: root.baseWindowWidth
        height: root.baseWindowHeight
        flags: Qt.WindowDoesNotAcceptFocus | Qt.FramelessWindowHint
        color: "transparent"
        visible: root.dockWindowVisible && !root.overlayVisible

        LayerShell.Window.scope: "macosdock-base"
        LayerShell.Window.anchors: {
            if (root.dockLocation === PlasmaCore.Types.TopEdge) {
                return LayerShell.Window.AnchorTop;
            }
            if (root.dockLocation === PlasmaCore.Types.LeftEdge) {
                return LayerShell.Window.AnchorLeft;
            }
            if (root.dockLocation === PlasmaCore.Types.RightEdge) {
                return LayerShell.Window.AnchorRight;
            }
            return LayerShell.Window.AnchorBottom;
        }
        LayerShell.Window.margins.left: root.panelEdgeMargin
        LayerShell.Window.margins.top: root.panelEdgeMargin
        LayerShell.Window.margins.right: root.panelEdgeMargin
        LayerShell.Window.margins.bottom: root.panelEdgeMargin
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.layer: LayerShell.Window.LayerOverlay
        LayerShell.Window.keyboardInteractivity:
            LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.activateOnShow: false
        LayerShell.Window.wantsToBeOnActiveScreen: true

        onVisibleChanged: {
            if (!visible) {
                root.baseHovered = false;
            }
        }

        Item {
            id: baseContent

            anchors.fill: parent
            transform: Translate {
                x: root.dockSlideX(baseWindow.width)
                y: root.dockSlideY(baseWindow.height)
            }

            DockBackground {
                id: baseSurface

                anchors.fill: parent
                surfaceOpacity: root.backgroundOpacity
                useThemeColor: root.useThemeBackground
                customColor: root.customBackgroundColor
                requestedRadius: root.cornerRadius
                borderOpacity: root.borderOpacity
                shadowOpacity: root.shadowOpacity
                showHighlight: root.showHighlight
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor

                onPointChanged: {
                    if (hovered) {
                        var coordinate = root.isVertical
                            ? point.position.y : point.position.x;
                        root.lastPointerMain = (root.overlayWindowMainLength
                            - root.baseWindowMainLength) / 2 + coordinate;
                    }
                }

                onHoveredChanged: {
                    root.baseHovered = hovered;
                    if (hovered) {
                        root.revealDock();
                        var coordinate = root.isVertical
                            ? point.position.y : point.position.x;
                        root.lastPointerMain = (root.overlayWindowMainLength
                            - root.baseWindowMainLength) / 2 + coordinate;
                        overlayCloseTimer.stop();
                        root.overlayOpen = true;
                    } else {
                        root.scheduleOverlayClose();
                        root.scheduleDockHide();
                    }
                }
            }

            Repeater {
                model: tasksModel

                delegate: TaskDelegate {
                    displayScale: 1.0
                    displayCrossExtent: root.baseIconSize
                    x: root.isVertical ? root.crossMargin
                        : root.mainMargin
                            + index * (root.baseIconSize + root.itemSpacing)
                    y: root.isVertical
                        ? root.mainMargin
                            + index * (root.baseIconSize + root.itemSpacing)
                        : root.crossMargin
                }
            }
        }
    }

    Window {
        id: edgeWindow

        objectName: "macOSDockEdge"
        title: "macOS Dock Edge"
        width: root.isVertical ? 4 : root.baseWindowMainLength
        height: root.isVertical ? root.baseWindowMainLength : 4
        flags: Qt.WindowDoesNotAcceptFocus | Qt.FramelessWindowHint
        color: "transparent"
        visible: root.dockAvailable && root.autoHideRequired
            && !root.dockWindowVisible

        LayerShell.Window.scope: "macosdock-edge"
        LayerShell.Window.anchors: {
            if (root.dockLocation === PlasmaCore.Types.TopEdge) {
                return LayerShell.Window.AnchorTop;
            }
            if (root.dockLocation === PlasmaCore.Types.LeftEdge) {
                return LayerShell.Window.AnchorLeft;
            }
            if (root.dockLocation === PlasmaCore.Types.RightEdge) {
                return LayerShell.Window.AnchorRight;
            }
            return LayerShell.Window.AnchorBottom;
        }
        LayerShell.Window.margins.left: 0
        LayerShell.Window.margins.top: 0
        LayerShell.Window.margins.right: 0
        LayerShell.Window.margins.bottom: 0
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.layer: LayerShell.Window.LayerOverlay
        LayerShell.Window.keyboardInteractivity:
            LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.activateOnShow: false
        LayerShell.Window.wantsToBeOnActiveScreen: true

        onVisibleChanged: {
            if (!visible) {
                root.edgeHovered = false;
                root.scheduleDockHide();
            }
        }

        Item {
            anchors.fill: parent

            HoverHandler {
                cursorShape: Qt.PointingHandCursor

                onHoveredChanged: {
                    root.edgeHovered = hovered;
                    if (hovered) {
                        root.revealDock();
                    } else {
                        root.scheduleDockHide();
                    }
                }
            }
        }
    }

    Window {
        id: overlayWindow

        objectName: "macOSDock"
        title: "macOS Dock"
        width: root.overlayWindowWidth
        height: root.overlayWindowHeight
        flags: Qt.WindowDoesNotAcceptFocus | Qt.FramelessWindowHint
        color: "transparent"
        visible: root.overlayVisible

        LayerShell.Window.scope: "macosdock"
        LayerShell.Window.anchors: {
            if (root.dockLocation === PlasmaCore.Types.TopEdge) {
                return LayerShell.Window.AnchorTop;
            }
            if (root.dockLocation === PlasmaCore.Types.LeftEdge) {
                return LayerShell.Window.AnchorLeft;
            }
            if (root.dockLocation === PlasmaCore.Types.RightEdge) {
                return LayerShell.Window.AnchorRight;
            }
            return LayerShell.Window.AnchorBottom;
        }
        LayerShell.Window.margins.left: root.panelEdgeMargin
        LayerShell.Window.margins.top: root.panelEdgeMargin
        LayerShell.Window.margins.right: root.panelEdgeMargin
        LayerShell.Window.margins.bottom: root.panelEdgeMargin
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.layer: LayerShell.Window.LayerOverlay
        LayerShell.Window.keyboardInteractivity:
            LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.activateOnShow: false
        LayerShell.Window.wantsToBeOnActiveScreen: true

        onVisibleChanged: {
            if (!visible) {
                root.overlayHovered = false;
            }
        }

        Item {
            id: overlayContent

            anchors.fill: parent
            transform: Translate {
                x: root.dockSlideX(overlayWindow.width)
                y: root.dockSlideY(overlayWindow.height)
            }

            readonly property real mainLength: root.isVertical ? height : width
            readonly property real currentMainLength: calculateCurrentMainLength()

            function scaleAt(index) {
                var item = overlayRepeater.itemAt(index);
                // Repeater.itemAt() is statically typed as Item, while every
                // delegate is a TaskDelegate/DockItem with currentScale.
                // qmllint disable missing-property
                var scale = item ? Number(item["currentScale"]) : 1.0;
                // qmllint enable missing-property
                return Number.isFinite(scale) ? scale : 1.0;
            }

            function calculateCurrentMainLength() {
                var count = root.taskCount;
                if (count <= 0) {
                    return 0;
                }

                var result = Math.max(0, count - 1) * root.itemSpacing;
                for (var index = 0; index < count; ++index) {
                    result += root.baseIconSize * scaleAt(index);
                }
                return result;
            }

            function centerForIndex(index) {
                var cursor = (mainLength - currentMainLength) / 2;
                for (var previous = 0; previous < index; ++previous) {
                    cursor += root.baseIconSize * scaleAt(previous)
                        + root.itemSpacing;
                }
                return cursor + root.baseIconSize * scaleAt(index) / 2;
            }

            DockBackground {
                id: overlayBackgroundSurface

                z: 0
                surfaceOpacity: root.backgroundOpacity
                useThemeColor: root.useThemeBackground
                customColor: root.customBackgroundColor
                requestedRadius: root.cornerRadius
                borderOpacity: root.borderOpacity
                shadowOpacity: root.shadowOpacity
                showHighlight: root.showHighlight
                x: root.isVertical
                    ? overlayContent.surfaceCrossStart(width)
                    : (overlayContent.width - width) / 2
                y: root.isVertical
                    ? (overlayContent.height - height) / 2
                    : overlayContent.surfaceCrossStart(height)
                width: root.isVertical
                    ? root.baseSurfaceCrossLength
                    : overlayContent.currentMainLength + 2 * root.mainMargin
                height: root.isVertical
                    ? overlayContent.currentMainLength + 2 * root.mainMargin
                    : root.baseSurfaceCrossLength
            }

            function surfaceCrossStart(surfaceCrossLength) {
                var crossLength = root.isVertical ? width : height;
                if (!root.isVertical) {
                    if (root.dockLocation === PlasmaCore.Types.TopEdge) {
                        return 0;
                    }
                    if (root.dockLocation === PlasmaCore.Types.BottomEdge) {
                        return crossLength - surfaceCrossLength;
                    }
                } else {
                    if (root.dockLocation === PlasmaCore.Types.LeftEdge) {
                        return 0;
                    }
                    if (root.dockLocation === PlasmaCore.Types.RightEdge) {
                        return crossLength - surfaceCrossLength;
                    }
                }
                return (crossLength - surfaceCrossLength) / 2;
            }

            HoverHandler {
                id: overlayHover

                cursorShape: Qt.PointingHandCursor
                onPointChanged: {
                    if (hovered) {
                        root.lastPointerMain = root.isVertical
                            ? point.position.y : point.position.x;
                    }
                }
                onHoveredChanged: {
                    root.overlayHovered = hovered;
                    if (hovered) {
                        root.revealDock();
                        root.overlayOpen = true;
                        root.lastPointerMain = root.isVertical
                            ? point.position.y : point.position.x;
                        overlayCloseTimer.stop();
                    } else {
                        root.scheduleOverlayClose();
                        root.scheduleDockHide();
                    }
                }
            }

            TapHandler {
                acceptedButtons: Qt.RightButton
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: dockMenu.popup()
            }

            QQC2.Menu {
                id: dockMenu

                property bool countedAsOpen: false
                closePolicy: QQC2.Popup.CloseOnEscape
                    | QQC2.Popup.CloseOnPressOutside
                    | QQC2.Popup.CloseOnReleaseOutside
                    | QQC2.Popup.CloseOnPressOutsideParent
                    | QQC2.Popup.CloseOnReleaseOutsideParent

                Component.onCompleted: root.configureContextMenu(dockMenu)

                onOpened: {
                    if (!countedAsOpen) {
                        countedAsOpen = true;
                        root.menuOpened(dockMenu);
                    }
                }
                onClosed: {
                    if (countedAsOpen) {
                        countedAsOpen = false;
                        root.menuClosed(dockMenu);
                    }
                }
                Component.onDestruction: {
                    if (countedAsOpen) {
                        root.menuClosed(dockMenu);
                    }
                }

                QQC2.MenuItem {
                    text: i18n("Configure Dock…")
                    icon.name: "configure"
                    onTriggered: Plasmoid.internalAction("configure").trigger()
                }
            }

            Item {
                id: overlaySurface

                z: 1

                x: root.isVertical
                    ? root.windowPadding + root.crossMargin : 0
                y: root.isVertical
                    ? 0 : root.windowPadding + root.crossMargin
                width: root.isVertical
                    ? root.maximumIconSize + root.indicatorSpace
                    : overlayContent.width
                height: root.isVertical
                    ? overlayContent.height
                    : root.maximumIconSize + root.indicatorSpace

                Repeater {
                    id: overlayRepeater

                    model: tasksModel

                    delegate: TaskDelegate {
                        displayScale: root.scaleForIndex(index,
                            root.lastPointerMain, root.overlayOpen,
                            overlayContent.mainLength, root.maxScale,
                            root.baseIconSize)
                        displayCrossExtent: root.maximumIconSize
                        x: root.isVertical ? 0
                            : overlayContent.centerForIndex(index) - scaledSize / 2
                        y: root.isVertical
                            ? overlayContent.centerForIndex(index) - scaledSize / 2 : 0
                    }
                }
            }
        }
    }
}
