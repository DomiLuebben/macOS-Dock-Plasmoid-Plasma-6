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

    readonly property real maxScale: Math.min(2.0,
        Math.max(1.0, Number(Plasmoid.configuration.maxScale) || 1.45))
    readonly property real zoomRadius: Math.min(200,
        Math.max(30, Number(Plasmoid.configuration.zoomRadius) || 70))
    readonly property real configuredIconSize: Number(
        Plasmoid.configuration.iconSize)
    readonly property int dockLocation: Plasmoid.formFactor
        === PlasmaCore.Types.Planar
        ? PlasmaCore.Types.BottomEdge : Plasmoid.location
    readonly property bool isVertical:
        dockLocation === PlasmaCore.Types.LeftEdge
        || dockLocation === PlasmaCore.Types.RightEdge
    readonly property real itemSpacing: 4
    readonly property real windowPadding: 10
    readonly property real mainMargin: Math.min(40,
        Math.max(4, Number(Plasmoid.configuration.dockMargin) || 16))
    readonly property real crossMargin: Math.min(20,
        Math.max(0, Number(Plasmoid.configuration.dockCrossMargin) || 0))
    readonly property real panelEdgeMargin: Math.min(32,
        Math.max(0, Number(Plasmoid.configuration.screenEdgeMargin) || 0))
    readonly property real backgroundOpacity: Math.min(0.9,
        Math.max(0.15, Number(Plasmoid.configuration.backgroundOpacity) || 0.55))
    readonly property bool hideOnMaximized:
        Plasmoid.configuration.hideOnMaximized === undefined
            ? true : Boolean(Plasmoid.configuration.hideOnMaximized)
    readonly property int launchAnimation: Math.max(0,
        Math.min(1, Number(Plasmoid.configuration.launchAnimation)))
    readonly property real indicatorSize: 3
    readonly property real indicatorGap: 2
    readonly property real indicatorSpace: indicatorSize + indicatorGap
    readonly property real baseIconSize: Math.min(96,
        Math.max(24, configuredIconSize || 44))
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
    }

    DockEffects.BlurRegion {
        window: edgeWindow
        region: Qt.rect(0, 0, 1, 1)
        radius: 0
    }

    function makePanelTransparent() {
        var containment = Plasmoid.containment;
        if (containment
                && Plasmoid.formFactor !== PlasmaCore.Types.Planar) {
            containment.backgroundHints = PlasmaCore.Types.NoBackground;
            containment.userBackgroundHints = PlasmaCore.Types.NoBackground;
        }
    }

    Component.onCompleted: makePanelTransparent()

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

    function menuOpened() {
        ++openMenuCount;
        overlayCloseTimer.stop();
        revealDock();
        overlayOpen = true;
    }

    function menuClosed() {
        openMenuCount = Math.max(0, openMenuCount - 1);
        scheduleOverlayClose();
        scheduleDockHide();
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

    function activateTask(row, launcher, active, minimized) {
        var index = modelIndex(row);
        if (launcher) {
            tasksModel.requestNewInstance(index);
        } else if (active && !minimized) {
            tasksModel.requestToggleMinimized(index);
        } else {
            tasksModel.requestActivate(index);
        }
    }

    function openTask(row, launcher) {
        var index = modelIndex(row);
        if (launcher) {
            tasksModel.requestNewInstance(index);
        } else {
            tasksModel.requestActivate(index);
        }
    }

    function toggleMinimized(row) {
        tasksModel.requestToggleMinimized(modelIndex(row));
    }

    function toggleMaximized(row) {
        tasksModel.requestToggleMaximized(modelIndex(row));
    }

    function launchNewInstance(row) {
        tasksModel.requestNewInstance(modelIndex(row));
    }

    function closeTask(row) {
        tasksModel.requestClose(modelIndex(row));
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
        readonly property bool pinned: root.launcherExists(model)
        readonly property string launcherTarget: root.launcherUrl(model)
        readonly property bool canOpenNewInstance: launcherOnly
            || model.CanLaunchNewInstance !== false

        appName: String(model.AppName || model.display || i18n("Anwendung"))
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
            root.activateTask(index, launcherOnly, Boolean(model.IsActive),
                Boolean(model.IsMinimized));
        }

        onNewInstanceRequested: {
            triggerBounce();
            root.launchNewInstance(index);
        }

        onContextMenuRequested: taskMenu.popup()

        QQC2.Menu {
            id: taskMenu

            property bool countedAsOpen: false

            onOpened: {
                if (!countedAsOpen) {
                    countedAsOpen = true;
                    root.menuOpened();
                }
            }
            onClosed: {
                if (countedAsOpen) {
                    countedAsOpen = false;
                    root.menuClosed();
                }
            }
            Component.onDestruction: {
                if (countedAsOpen) {
                    root.menuClosed();
                }
            }

            QQC2.MenuItem {
                text: taskDelegate.runningTask
                    ? i18n("Aktivieren") : i18n("Öffnen")
                icon.name: taskDelegate.runningTask ? "window" : "system-run"
                onTriggered: root.openTask(taskDelegate.index,
                    taskDelegate.launcherOnly)
            }

            QQC2.MenuItem {
                text: i18n("Neues Fenster")
                icon.name: "window-new"
                visible: taskDelegate.canOpenNewInstance
                onTriggered: root.launchNewInstance(taskDelegate.index)
            }

            QQC2.MenuSeparator {}

            QQC2.MenuItem {
                text: taskDelegate.pinned
                    ? i18n("Vom Dock lösen") : i18n("Im Dock behalten")
                icon.name: taskDelegate.pinned ? "list-remove" : "bookmark-new"
                enabled: taskDelegate.launcherTarget.length > 0
                onTriggered: root.toggleLauncher(taskDelegate.model)
            }

            QQC2.MenuItem {
                text: root.isVertical ? i18n("Nach oben") : i18n("Nach links")
                icon.name: root.isVertical ? "go-up" : "go-previous"
                visible: taskDelegate.pinned
                enabled: taskDelegate.index > 0
                onTriggered: root.moveTask(taskDelegate.index, -1)
            }

            QQC2.MenuItem {
                text: root.isVertical ? i18n("Nach unten") : i18n("Nach rechts")
                icon.name: root.isVertical ? "go-down" : "go-next"
                visible: taskDelegate.pinned
                enabled: taskDelegate.index < root.taskCount - 1
                onTriggered: root.moveTask(taskDelegate.index, 1)
            }

            QQC2.MenuSeparator {
                visible: taskDelegate.runningTask
            }

            QQC2.MenuItem {
                text: Boolean(taskDelegate.model.IsMinimized)
                    ? i18n("Wiederherstellen") : i18n("Minimieren")
                icon.name: Boolean(taskDelegate.model.IsMinimized)
                    ? "window-restore" : "window-minimize"
                visible: taskDelegate.runningTask
                enabled: Boolean(taskDelegate.model.IsMinimizable)
                onTriggered: root.toggleMinimized(taskDelegate.index)
            }

            QQC2.MenuItem {
                text: Boolean(taskDelegate.model.IsMaximized)
                    ? i18n("Wiederherstellen") : i18n("Maximieren")
                icon.name: Boolean(taskDelegate.model.IsMaximized)
                    ? "window-restore" : "window-maximize"
                visible: taskDelegate.runningTask
                enabled: Boolean(taskDelegate.model.IsMaximizable)
                onTriggered: root.toggleMaximized(taskDelegate.index)
            }

            QQC2.MenuItem {
                text: i18n("Schließen")
                icon.name: "window-close"
                visible: taskDelegate.runningTask
                enabled: Boolean(taskDelegate.model.IsClosable)
                onTriggered: root.closeTask(taskDelegate.index)
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
                var countDependency = root.taskCount;
                var item = overlayRepeater.itemAt(index);
                return item ? item.currentScale : 1.0;
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
                var countDependency = root.taskCount;
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
                        return root.windowPadding;
                    }
                    if (root.dockLocation === PlasmaCore.Types.BottomEdge) {
                        return crossLength - root.windowPadding
                            - surfaceCrossLength;
                    }
                } else {
                    if (root.dockLocation === PlasmaCore.Types.LeftEdge) {
                        return root.windowPadding;
                    }
                    if (root.dockLocation === PlasmaCore.Types.RightEdge) {
                        return crossLength - root.windowPadding
                            - surfaceCrossLength;
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

                onOpened: {
                    if (!countedAsOpen) {
                        countedAsOpen = true;
                        root.menuOpened();
                    }
                }
                onClosed: {
                    if (countedAsOpen) {
                        countedAsOpen = false;
                        root.menuClosed();
                    }
                }

                QQC2.MenuItem {
                    text: i18n("Dock einrichten …")
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
