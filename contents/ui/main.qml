pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtCore
import org.kde.kirigami as Kirigami
import org.kde.layershell as LayerShell
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.private.sessions as Sessions
import org.kde.taskmanager as TaskManager
import org.kde.private.desktopcontainment.folder as Folder
import "effects" as DockEffects
import "AppGroupStore.js" as AppGroupStore

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.userBackgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.constraintHints: Plasmoid.NoHint

    preferredRepresentation: fullRepresentation
    activationTogglesExpanded: false
    switchWidth: 1
    switchHeight: 1

    readonly property real maxScale: boundedNumber(
        Plasmoid.configuration.maxScale, 1.45, 1.0, 2.0)
    readonly property real zoomRadius: boundedNumber(
        Plasmoid.configuration.zoomRadius, 70, 30, 200)
    readonly property real configuredIconSize: boundedNumber(
        Plasmoid.configuration.iconSize, 44, 24, 96)
    readonly property int configuredDockPosition: Math.round(boundedNumber(
        Plasmoid.configuration.dockPosition, 0, 0, 2))
    readonly property int configuredDockLocation:
        configuredDockPosition === 1 ? PlasmaCore.Types.LeftEdge
        : configuredDockPosition === 2 ? PlasmaCore.Types.RightEdge
        : PlasmaCore.Types.BottomEdge
    readonly property int dockLocation: Plasmoid.formFactor
        === PlasmaCore.Types.Planar
        ? configuredDockLocation : Plasmoid.location
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
    readonly property bool showFolderView:
        Plasmoid.configuration.showFolderView === undefined
            ? true : Boolean(Plasmoid.configuration.showFolderView)
    readonly property int folderViewMode: Math.round(boundedNumber(
        Plasmoid.configuration.folderViewMode, 0, 0, 2))
    readonly property bool showTrash:
        Plasmoid.configuration.showTrash === undefined
            ? true : Boolean(Plasmoid.configuration.showTrash)
    readonly property bool showRemovableVolumes:
        Plasmoid.configuration.showRemovableVolumes === undefined
            ? true : Boolean(Plasmoid.configuration.showRemovableVolumes)
    property bool isVolumeDragOverTrash: false

    readonly property int removableVolumeCount: showRemovableVolumes
        ? removableVolumesModel.count : 0

    readonly property bool showPowerButton:
        Plasmoid.configuration.showPowerButton === undefined
            ? true : Boolean(Plasmoid.configuration.showPowerButton)
    readonly property int powerButtonPosition: Math.round(boundedNumber(
        Plasmoid.configuration.powerButtonPosition, 1, 0, 1))
    readonly property bool showDesktopSwitcher:
        Plasmoid.configuration.showDesktopSwitcher === undefined
            ? true : Boolean(Plasmoid.configuration.showDesktopSwitcher)
    readonly property int desktopSwitcherPosition: Math.round(boundedNumber(
        Plasmoid.configuration.desktopSwitcherPosition, 0, 0, 1))
    readonly property int desktopSwitcherLabelMode: Math.round(boundedNumber(
        Plasmoid.configuration.desktopSwitcherLabelMode, 0, 0, 1))
    readonly property url defaultFolderUrl: StandardPaths.writableLocation(
        StandardPaths.DownloadLocation)
    readonly property url configuredFolderUrl:
        String(Plasmoid.configuration.folderUrl || "").length > 0
            ? Plasmoid.configuration.folderUrl : defaultFolderUrl
    readonly property var additionalFolderUrls:
        Plasmoid.configuration.folderUrls || []
    readonly property real indicatorSize: 3
    readonly property real indicatorGap: 2
    readonly property real indicatorSpace: indicatorSize + indicatorGap
    readonly property real baseIconSize: configuredIconSize
    readonly property real baseSurfaceCrossLength:
        baseIconSize + indicatorSpace + 2 * crossMargin
    readonly property real baseSurfaceMainLength: preferredMainLength
    readonly property real maximumIconSize: baseIconSize * maxScale
    readonly property int taskCount: tasksModel.count
    property int taskLayoutRevision: 0
    readonly property var appGroups:
        parseAppGroups(Plasmoid.configuration.appGroups || [])
    readonly property var taskLayout: {
        // QAbstractItemModel role changes are not directly observable from a
        // JavaScript helper. This revision makes the layout binding explicit.
        void taskLayoutRevision;
        void appGroups;
        var launcherUrls = [];
        for (var row = 0; row < taskCount; ++row) {
            launcherUrls.push(launcherUrlAtTaskRow(row));
        }
        return AppGroupStore.buildLayout(launcherUrls, appGroups);
    }
    readonly property int taskVisualCount:
        taskLayout.modelByVisual.length
    readonly property int desktopCount:
        virtualDesktopInfo.numberOfDesktops
    readonly property bool desktopSwitcherVisible:
        showDesktopSwitcher && desktopCount > 0
    readonly property bool desktopSwitcherOnLeft:
        desktopSwitcherPosition === 0
    readonly property bool desktopAddButtonVisible:
        desktopSwitcherVisible && !desktopCreationPending
    readonly property real desktopButtonSpacing: 4
    readonly property real desktopAddButtonMainExtent:
        Math.max(26, Math.round(baseIconSize * 0.6))
    readonly property int folderItemCount: showFolderView
        ? 1 + additionalFolderUrls.length : 0
    readonly property bool powerButtonOnLeft:
        showPowerButton && powerButtonPosition === 0
    // Dock indices describe visual order along the main axis. A leading power
    // button occupies slot zero, so task drag and magnification use this offset.
    readonly property int taskDockStartIndex:
        powerButtonOnLeft ? 1 : 0
    readonly property int folderDockIndex:
        folderItemCount > 0
            ? taskDockStartIndex + taskVisualCount : -1
    readonly property int removableVolumeDockStartIndex:
        removableVolumeCount > 0
            ? taskDockStartIndex + taskVisualCount + folderItemCount : -1
    readonly property int trashDockIndex: showTrash
        ? taskDockStartIndex + taskVisualCount + folderItemCount
            + removableVolumeCount : -1
    readonly property int powerButtonDockIndex: showPowerButton
        ? (powerButtonOnLeft ? 0
            : taskVisualCount + folderItemCount + removableVolumeCount
                + (showTrash ? 1 : 0)) : -1
    readonly property int trailingUtilityItemCount:
        folderItemCount + removableVolumeCount + (showTrash ? 1 : 0)
            + (showPowerButton && !powerButtonOnLeft ? 1 : 0)
    readonly property int utilityItemCount:
        folderItemCount + removableVolumeCount + (showTrash ? 1 : 0) + (showPowerButton ? 1 : 0)
    readonly property int dockItemCount: taskVisualCount + utilityItemCount
    readonly property bool leadingUtilitySeparatorVisible:
        powerButtonOnLeft && dockItemCount > 1
    readonly property bool trailingUtilitySeparatorVisible:
        taskVisualCount > 0 && trailingUtilityItemCount > 0
    readonly property var sectionBreakAfterDockIndices: {
        var result = [];
        if (leadingUtilitySeparatorVisible) {
            result.push(powerButtonDockIndex);
        }
        if (trailingUtilitySeparatorVisible) {
            result.push(taskDockStartIndex + taskVisualCount - 1);
        }
        return result;
    }
    readonly property real utilitySectionGap:
        12
    readonly property real iconRestMainLength: dockItemCount > 0
        ? dockItemCount * baseIconSize
            + (dockItemCount - 1) * itemSpacing
            + sectionBreakAfterDockIndices.length * utilitySectionGap : 0
    readonly property real desktopSwitcherMainExtent:
        desktopSwitcherVisible ? calculateDesktopSwitcherMainExtent() : 0
    readonly property real desktopSwitcherSectionSpacing:
        desktopSwitcherVisible && dockItemCount > 0 ? 16 : 0
    readonly property real desktopSwitcherLeadingExtent:
        desktopSwitcherVisible && desktopSwitcherOnLeft
            ? desktopSwitcherMainExtent + desktopSwitcherSectionSpacing : 0
    readonly property real restMainLength: iconRestMainLength
        + desktopSwitcherMainExtent + desktopSwitcherSectionSpacing
    readonly property real maximumExpansion:
        maximumWaveExpansion(dockItemCount)
    readonly property bool hasDockContent:
        dockItemCount > 0 || desktopSwitcherVisible
    readonly property real preferredMainLength: hasDockContent
        ? restMainLength + 2 * mainMargin : Kirigami.Units.gridUnit
    readonly property real maximumOverlayMainLength: hasDockContent
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
    Layout.maximumWidth: 1
    Layout.maximumHeight: 1
    Layout.fillWidth: false
    Layout.fillHeight: false

    width: 1
    height: 1
    implicitWidth: 1
    implicitHeight: 1

    property bool taskModelReady: false
    property bool overlayOpen: false
    readonly property bool dockAvailable: hasDockContent
        && representationItem !== null
    readonly property bool showProgressIndicators:
        Plasmoid.configuration.showProgressIndicators === undefined
            ? true : Boolean(Plasmoid.configuration.showProgressIndicators)

    readonly property bool showKdeConnectRecentShares:
        Plasmoid.configuration.showKdeConnectRecentShares === undefined
            ? true : Boolean(Plasmoid.configuration.showKdeConnectRecentShares)

    ProgressController {
        id: progressController
        monitoringEnabled: root.showProgressIndicators
    }

    DockEffects.KdeConnectShareMonitor {
        id: kdeConnectMonitor
        enabled: root.showKdeConnectRecentShares
    }

    DockEffects.RemovableVolumesModel {
        id: removableVolumesModel
        onOperationFailed: (udi, message) => {
            console.warn("macOS Dock: volume operation failed for", udi, ":", message);
        }
    }
    readonly property var recentKdeConnectShares:
        kdeConnectMonitor.recentShares
    property bool maximizedWindowPresent: false
    property bool fullscreenWindowPresent: false
    property bool windowStateUpdatePending: false
    readonly property bool autoHideRequired:
        fullscreenWindowPresent
            || (hideOnMaximized && maximizedWindowPresent)
    property bool revealedForMaximized: false
    readonly property bool dockRequestedVisible: dockAvailable
        && !fullscreenWindowPresent
        && (!autoHideRequired || revealedForMaximized
            || baseHovered || overlayHovered || openMenuCount > 0
            || openPreviewCount > 0)
    property real dockRevealProgress: dockRequestedVisible ? 1.0 : 0.0
    readonly property bool dockWindowVisible: dockAvailable
        && (dockRequestedVisible || dockRevealProgress > 0.001)
    readonly property bool overlayVisible: overlayOpen && dockWindowVisible
    property Item representationItem: null
    property bool baseHovered: false
    property bool overlayHovered: false
    property bool edgeHovered: false
    property int openMenuCount: 0
    property int openPreviewCount: 0
    property bool folderPopupCountedAsOpen: false
    property bool folderPopupOpenPending: false
    property bool appGroupPopupCountedAsOpen: false
    property bool appGroupPopupOpenPending: false
    property string activeAppGroupId: ""
    property bool folderDropActive: false
    property url activeFolderUrl: configuredFolderUrl
    property bool desktopCreationPending: false
    property int trashItemCount: 0
    property var openContextMenu: null
    property real lastPointerMain: isVertical
        ? overlayWindowHeight / 2 : overlayWindowWidth / 2

    Behavior on dockRevealProgress {
        NumberAnimation {
            duration: root.dockRequestedVisible ? 240 : 300
            easing.type: root.dockRequestedVisible
                ? Easing.OutCubic : Easing.InCubic
        }
    }

    FontMetrics {
        id: desktopLabelMetrics

        font.pixelSize: 13
        font.weight: Font.DemiBold
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

        onVirtualDesktopCreationFinished:
            root.desktopCreationPending = false
    }

    Sessions.SessionManagement {
        id: sessionManagement
    }

    function boundedNumber(value, fallback, minimum, maximum) {
        var number = Number(value);
        if (!Number.isFinite(number)) {
            number = fallback;
        }
        return Math.min(maximum, Math.max(minimum, number));
    }

    function desktopIdAt(index) {
        var ids = virtualDesktopInfo.desktopIds || [];
        return index >= 0 && index < ids.length ? String(ids[index]) : "";
    }

    function desktopNameAt(index) {
        var names = virtualDesktopInfo.desktopNames || [];
        if (index >= 0 && index < names.length
                && String(names[index]).length > 0) {
            return String(names[index]);
        }
        return i18n("Desktop %1", index + 1);
    }

    function desktopLabelAt(index) {
        return desktopSwitcherLabelMode === 0
            ? String(index + 1) : desktopNameAt(index);
    }

    function desktopButtonMainExtent(index) {
        if (desktopSwitcherLabelMode === 0) {
            return Math.max(26, Math.round(baseIconSize * 0.6));
        }
        return Math.max(56, Math.min(160,
            desktopLabelMetrics.advanceWidth(desktopLabelAt(index)) + 24));
    }

    function desktopButtonMainStart(index) {
        var result = 0;
        for (var previous = 0; previous < index; ++previous) {
            result += desktopButtonMainExtent(previous)
                + desktopButtonSpacing;
        }
        return result;
    }

    function calculateDesktopSwitcherMainExtent() {
        var result = 0;
        for (var index = 0; index < desktopCount; ++index) {
            result += desktopButtonMainExtent(index);
            if (index < desktopCount - 1) {
                result += desktopButtonSpacing;
            }
        }
        if (desktopAddButtonVisible) {
            if (desktopCount > 0) {
                result += desktopButtonSpacing;
            }
            result += desktopAddButtonMainExtent;
        }
        return result;
    }

    function isDesktopActive(index) {
        return desktopIdAt(index)
            === String(virtualDesktopInfo.currentDesktop || "");
    }

    function activateDesktop(index) {
        if (index >= 0 && index < desktopCount) {
            windowActions.requestVirtualDesktopActivation(index + 1);
        }
    }

    function createDesktop() {
        if (desktopCreationPending) {
            return;
        }
        desktopCreationPending = true;
        if (!windowActions.createVirtualDesktop(desktopCount)) {
            desktopCreationPending = false;
        }
    }

    function folderUrlAt(index) {
        if (index === 0) {
            return configuredFolderUrl;
        }
        var additionalIndex = index - 1;
        return additionalIndex >= 0
                && additionalIndex < additionalFolderUrls.length
            ? additionalFolderUrls[additionalIndex] : "";
    }

    function folderName(folderUrl) {
        var path = String(folderUrl || "").replace(/\/$/, "");
        try {
            path = decodeURIComponent(path);
        } catch (error) {
            // A malformed escape sequence must not break Dock delegates.
        }
        var slash = path.lastIndexOf("/");
        var name = slash >= 0 ? path.substring(slash + 1) : path;
        return name.length > 0 ? name : i18n("Folder");
    }

    function folderIconName(folderUrl) {
        var candidate = comparableFolderUrl(folderUrl);
        var downloads = comparableFolderUrl(defaultFolderUrl);
        return candidate.length > 0 && candidate === downloads
            ? "folder-download" : "folder";
    }

    function comparableFolderUrl(folderUrl) {
        var canonical = windowActions.canonicalDirectoryUrl(folderUrl);
        if (canonical.length > 0) {
            return canonical;
        }
        return String(folderUrl || "").replace(/\/$/, "");
    }

    function containsFolderUrl(folderUrls, candidate) {
        var comparableCandidate = comparableFolderUrl(candidate);
        if (comparableCandidate.length === 0) {
            return false;
        }
        for (var index = 0; index < folderUrls.length; ++index) {
            if (comparableFolderUrl(folderUrls[index])
                    === comparableCandidate) {
                return true;
            }
        }
        return false;
    }

    function droppedUrlsContainFolder(urls) {
        var values = urls || [];
        for (var index = 0; index < values.length; ++index) {
            if (windowActions.canonicalDirectoryUrl(values[index]).length > 0) {
                return true;
            }
        }
        return false;
    }

    function addDroppedFolders(urls) {
        var next = [];
        for (var existingIndex = 0;
                existingIndex < additionalFolderUrls.length;
                ++existingIndex) {
            next.push(String(additionalFolderUrls[existingIndex]));
        }

        var changed = false;
        var values = urls || [];
        for (var index = 0; index < values.length; ++index) {
            var folderUrl = windowActions.canonicalDirectoryUrl(values[index]);
            if (folderUrl.length === 0
                    || comparableFolderUrl(configuredFolderUrl)
                        === comparableFolderUrl(folderUrl)
                    || containsFolderUrl(next, folderUrl)) {
                continue;
            }
            next.push(folderUrl);
            changed = true;
        }

        if (changed) {
            Plasmoid.configuration.folderUrls = next;
            Plasmoid.configuration.showFolderView = true;
            revealDock();
            overlayOpen = true;
        }
        return changed;
    }

    function removeAdditionalFolder(folderUrl) {
        var target = comparableFolderUrl(folderUrl);
        var next = [];
        var changed = false;
        for (var index = 0; index < additionalFolderUrls.length; ++index) {
            if (comparableFolderUrl(additionalFolderUrls[index]) === target) {
                changed = true;
            } else {
                next.push(String(additionalFolderUrls[index]));
            }
        }
        if (changed) {
            if (comparableFolderUrl(activeFolderUrl) === target) {
                closeFolderPopup();
            }
            Plasmoid.configuration.folderUrls = next;
        }
    }

    function openFolderExternally(folderUrl) {
        Folder.AppLauncher.openUrl(folderUrl || configuredFolderUrl);
    }

    function openTrashExternally() {
        Folder.AppLauncher.openUrl("trash:/");
    }

    function emptyTrash() {
        trashModel.emptyTrashBin();
    }

    function toggleFolderPopup(folderUrl, visualParent) {
        var targetUrl = String(folderUrl || configuredFolderUrl);
        var sameTarget = comparableFolderUrl(activeFolderUrl)
            === comparableFolderUrl(targetUrl);
        if ((folderPopup.visible || folderPopupOpenPending) && sameTarget) {
            closeFolderPopup();
            return;
        }
        if (folderPopup.visible) {
            folderPopup.close();
        }
        activeFolderUrl = targetUrl;
        folderModel.url = targetUrl;
        revealDock();
        overlayOpen = true;
        folderPopup.visualParent = visualParent;
        if (!folderPopupOpenPending) {
            folderPopupOpenPending = true;
            Qt.callLater(runScheduledFolderPopupOpen);
        }
    }

    function runScheduledFolderPopupOpen() {
        if (!folderPopupOpenPending) {
            return;
        }
        folderPopupOpenPending = false;
        if (showFolderView && folderPopup.visualParent) {
            folderPopup.showPopup();
        }
    }

    function closeFolderPopup() {
        folderPopupOpenPending = false;
        if (folderPopup.visible) {
            folderPopup.close();
        }
    }

    function toggleAppGroupPopup(groupId, visualParent) {
        var group = appGroupById(groupId);
        if (!group) {
            return;
        }
        var sameTarget = activeAppGroupId === group.id;
        if ((appGroupPopup.visible || appGroupPopupOpenPending)
                && sameTarget) {
            closeAppGroupPopup();
            return;
        }
        closeFolderPopup();
        if (appGroupPopup.visible) {
            appGroupPopup.hidePopup();
        }
        activeAppGroupId = group.id;
        appGroupPopup.groupId = group.id;
        appGroupPopup.groupName = group.name;
        appGroupPopup.members = groupRuntimeMembers(group);
        appGroupPopup.visualParent = visualParent;
        revealDock();
        overlayOpen = true;
        if (!appGroupPopupOpenPending) {
            appGroupPopupOpenPending = true;
            Qt.callLater(runScheduledAppGroupPopupOpen);
        }
    }

    function runScheduledAppGroupPopupOpen() {
        if (!appGroupPopupOpenPending) {
            return;
        }
        appGroupPopupOpenPending = false;
        if (appGroupById(activeAppGroupId)
                && appGroupPopup.visualParent) {
            appGroupPopup.showPopup();
        }
    }

    function closeAppGroupPopup() {
        appGroupPopupOpenPending = false;
        if (appGroupPopup.visible) {
            appGroupPopup.hidePopup();
        }
    }

    function updateActiveAppGroupPopup() {
        if (!activeAppGroupId) {
            return;
        }
        var group = appGroupById(activeAppGroupId);
        if (!group) {
            closeAppGroupPopup();
            activeAppGroupId = "";
            return;
        }
        appGroupPopup.groupName = group.name;
        appGroupPopup.members = groupRuntimeMembers(group);
    }

    function updateTrashCount() {
        trashItemCount = trashModel.rowCount();
    }

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
        if (!active || index < 0 || index >= dockItemCount) {
            return 1.0;
        }

        var firstCenter = (mainLength - restMainLength) / 2
            + iconSize / 2;
        var center = firstCenter + dockIndexOffset(index);
        return waveScale(Math.abs(pointer - center), maximum);
    }

    function maximumWaveExpansion(count) {
        if (count <= 0 || maxScale <= 1.0) {
            return 0;
        }

        var sampleCount = Math.max(1, (count - 1) * 8);
        var largest = 0;

        for (var sample = 0; sample <= sampleCount; ++sample) {
            var pointer = baseIconSize / 2
                + sample * Math.max(baseIconSize, restMainLength - baseIconSize)
                    / sampleCount;
            var expansion = 0;
            for (var index = 0; index < count; ++index) {
                var center = baseIconSize / 2 + dockIndexOffset(index);
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
                && !edgeHovered && openMenuCount === 0
                && openPreviewCount === 0) {
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

    function closeTaskPreviewsIn(repeater) {
        if (!repeater) {
            return;
        }
        for (var index = 0; index < repeater.count; ++index) {
            var delegate = repeater.itemAt(index);
            if (delegate) {
                delegate.setPreviewOpen(false);
            }
        }
    }

    function closeTransientUi() {
        closeOpenContextMenu();
        closeFolderPopup();
        closeAppGroupPopup();
        closeTaskPreviewsIn(baseRepeater);
        closeTaskPreviewsIn(overlayRepeater);
    }

    function previewOpened() {
        ++openPreviewCount;
        overlayCloseTimer.stop();
        dockHideTimer.stop();
        revealDock();
        overlayOpen = true;
    }

    function previewClosed() {
        openPreviewCount = Math.max(0, openPreviewCount - 1);
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

    function taskRole(index, role) {
        return tasksModel.data(index, role);
    }

    function updateScreenWindowState() {
        windowStateUpdatePending = false;
        var maximizedPresent = false;
        var fullscreenPresent = false;
        for (var row = 0; row < screenWindowsModel.count; ++row) {
            var index = screenWindowsModel.makeModelIndex(row);
            maximizedPresent = maximizedPresent || Boolean(
                screenWindowsModel.data(index,
                    TaskManager.AbstractTasksModel.IsMaximized));
            fullscreenPresent = fullscreenPresent || Boolean(
                screenWindowsModel.data(index,
                    TaskManager.AbstractTasksModel.IsFullScreen));
            if (maximizedPresent && fullscreenPresent) {
                break;
            }
        }
        maximizedWindowPresent = maximizedPresent;
        fullscreenWindowPresent = fullscreenPresent;
    }

    function scheduleScreenWindowStateUpdate() {
        if (windowStateUpdatePending) {
            return;
        }
        windowStateUpdatePending = true;
        Qt.callLater(updateScreenWindowState);
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

    function windowsInfoForTask(row, modelChildCount) {
        var parentIndex = modelIndex(row);
        if (!parentIndex || !parentIndex.valid) {
            return [];
        }
        var isGroupParent = isGroup(row);
        var result = [];
        if (isGroupParent) {
            var childCount = tasksModel.rowCount(parentIndex);
            for (var child = 0; child < childCount; ++child) {
                var childIndex = tasksModel.makeModelIndex(row, child);
                var persistentChildIndex =
                    tasksModel.makePersistentModelIndex(row, child);
                var winIdList = taskRole(childIndex, TaskManager.AbstractTasksModel.WinIdList);
                var winId = (winIdList && winIdList.length > 0) ? winIdList[0] : 0;
                var name = taskRole(childIndex, Qt.DisplayRole)
                    || taskRole(childIndex,
                        TaskManager.AbstractTasksModel.AppName) || "";
                var isActive = Boolean(taskRole(childIndex, TaskManager.AbstractTasksModel.IsActive));
                var isMinimized = Boolean(taskRole(childIndex, TaskManager.AbstractTasksModel.IsMinimized));
                result.push({
                    winId: winId,
                    title: String(name),
                    modelIndex: persistentChildIndex,
                    isActive: isActive,
                    isMinimized: isMinimized
                });
            }
        } else {
            var winIdList = taskRole(parentIndex, TaskManager.AbstractTasksModel.WinIdList);
            var winId = (winIdList && winIdList.length > 0) ? winIdList[0] : 0;
            var name = taskRole(parentIndex, Qt.DisplayRole)
                || taskRole(parentIndex,
                    TaskManager.AbstractTasksModel.AppName) || "";
            var isActive = Boolean(taskRole(parentIndex, TaskManager.AbstractTasksModel.IsActive));
            var isMinimized = Boolean(taskRole(parentIndex, TaskManager.AbstractTasksModel.IsMinimized));
            result.push({
                winId: winId,
                title: String(name),
                modelIndex: tasksModel.makePersistentModelIndex(row),
                isActive: isActive,
                isMinimized: isMinimized
            });
        }
        return result;
    }

    // Layer-Shell-Flächen kennen ihre eigene Bildschirmposition nicht: der
    // Compositor platziert sie, Qt lässt QWindow::position() auf (0,0) stehen.
    // mapToGlobal() liefert hier also Fenster- statt Bildschirmkoordinaten.
    //
    // Die Position ist trotzdem exakt berechenbar: die Fläche ist an genau
    // eine Kante verankert und wird auf der freien Achse zentriert (so
    // definiert es das Layer-Shell-Protokoll für Flächen mit nur einem Anker).
    function windowScreenOrigin(windowItem) {
        if (!windowItem) {
            return null;
        }
        var screenItem = windowItem.screen;
        if (!screenItem) {
            return null;
        }
        // Nur die Kante, an der die Fläche verankert ist, bekommt einen Rand.
        var edgeMargin = windowItem === edgeWindow ? 0 : root.panelEdgeMargin;
        var originX;
        var originY;
        if (root.isVertical) {
            originY = screenItem.virtualY
                + (screenItem.height - windowItem.height) / 2;
            originX = root.dockLocation === PlasmaCore.Types.LeftEdge
                ? screenItem.virtualX + edgeMargin
                : screenItem.virtualX + screenItem.width
                    - windowItem.width - edgeMargin;
        } else {
            originX = screenItem.virtualX
                + (screenItem.width - windowItem.width) / 2;
            originY = root.dockLocation === PlasmaCore.Types.TopEdge
                ? screenItem.virtualY + edgeMargin
                : screenItem.virtualY + screenItem.height
                    - windowItem.height - edgeMargin;
        }
        return Qt.point(originX, originY);
    }

    function publishDelegateGeometry(row, delegateItem, windowItem) {
        if (!root.taskModelReady || row < 0 || row >= root.taskCount
                || !delegateItem || !windowItem || !windowItem.visible) {
            return;
        }
        var parentIndex = modelIndex(row);
        if (!parentIndex || !parentIndex.valid) {
            return;
        }

        // XWindowTasksModel wertet diesen Rahmen als Bildschirmkoordinaten aus
        // (_NET_WM_ICON_GEOMETRY) — für XWayland-Anwendungen muss er stimmen.
        // WaylandTasksModel ignoriert ihn und leitet die Geometrie selbst aus
        // dem übergebenen Delegate ab, deshalb ist dort ausschlaggebend, dass
        // dieses Item zu einer gemappten Fläche gehört.
        var origin = windowScreenOrigin(windowItem);
        var globalRect;
        if (origin) {
            var scenePos = delegateItem.mapToItem(null, 0, 0);
            globalRect = Qt.rect(origin.x + scenePos.x, origin.y + scenePos.y,
                delegateItem.width, delegateItem.height);
        } else {
            var globalPos = delegateItem.mapToGlobal(0, 0);
            globalRect = Qt.rect(globalPos.x, globalPos.y,
                delegateItem.width, delegateItem.height);
        }

        // TasksModel propagates a group parent's geometry to all children.
        tasksModel.requestPublishDelegateGeometry(parentIndex, globalRect,
            delegateItem);
    }

    // Basis-, Overlay- und Kantenfenster lösen einander ab. Wird eines gerade
    // erst gemappt, kann die Veröffentlichung noch auf eine fehlende Fläche
    // treffen; ein zweiter Durchlauf kurz danach fängt das ab.
    function republishTaskGeometry() {
        var repeaters = [baseRepeater, overlayRepeater, edgeGeometryRepeater];
        for (var r = 0; r < repeaters.length; ++r) {
            var repeater = repeaters[r];
            if (!repeater) {
                continue;
            }
            for (var i = 0; i < repeater.count; ++i) {
                var item = repeater.itemAt(i);
                if (!item) {
                    continue;
                }
                if (item.scheduleGeometryPublish) {
                    item.scheduleGeometryPublish();
                } else if (item.publishEdgeGeometry) {
                    item.publishEdgeGeometry();
                }
            }
        }
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

    function normalizedLauncherUrl(value) {
        return AppGroupStore.normalizeLauncherUrl(value);
    }

    function parseAppGroups(serializedGroups) {
        return AppGroupStore.parse(serializedGroups,
            i18n("Application"), i18n("Group"));
    }

    function saveAppGroups(groups) {
        Plasmoid.configuration.appGroups =
            AppGroupStore.serialize(groups);
        scheduleTaskLayoutRefresh();
    }

    function launcherUrlAtTaskRow(row) {
        if (!taskModelReady || row < 0 || row >= taskCount) {
            return "";
        }
        var index = modelIndex(row);
        return normalizedLauncherUrl(
            taskRole(index,
                TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon)
            || taskRole(index, TaskManager.AbstractTasksModel.LauncherUrl)
            || "");
    }

    function appGroupForLauncher(launcherUrl) {
        return AppGroupStore.findGroupForLauncher(
            appGroups, launcherUrl);
    }

    function appGroupById(groupId) {
        return AppGroupStore.findGroupById(appGroups, groupId);
    }

    function appGroupForTask(row, launcherTarget) {
        var launcher = normalizedLauncherUrl(launcherTarget);
        if (!launcher) {
            launcher = launcherUrlAtTaskRow(row);
        }
        return appGroupForLauncher(launcher);
    }

    function appGroupIdForTask(row) {
        return row >= 0 && row < taskLayout.groupIdByRow.length
            ? taskLayout.groupIdByRow[row] : "";
    }

    function stableVisualIndexForModelIndex(row) {
        return row >= 0 && row < taskLayout.visualByRow.length
            ? taskLayout.visualByRow[row] : -1;
    }

    function stableModelIndexForVisualIndex(visualIndex) {
        return visualIndex >= 0
            && visualIndex < taskLayout.modelByVisual.length
            ? taskLayout.modelByVisual[visualIndex] : -1;
    }

    function isAppGroupLeaderTask(row, groupId) {
        return AppGroupStore.isLeader(taskLayout, row, groupId);
    }

    function taskDelegateForRow(row) {
        if (row < 0) {
            return null;
        }
        return baseRepeater.itemAt(row) || overlayRepeater.itemAt(row);
    }

    function fallbackIconName(launcherUrl, appId) {
        var iconName = String(appId || "").trim();
        if (iconName) {
            if (iconName.toLowerCase().endsWith(".desktop")) {
                iconName = iconName.substring(0, iconName.length - 8);
            }
            return iconName;
        }
        var launcher = normalizedLauncherUrl(launcherUrl);
        launcher = launcher.replace(/^application:\/\//, "")
            .replace(/^applications:/, "");
        var slashIndex = launcher.lastIndexOf("/");
        if (slashIndex >= 0) {
            launcher = launcher.substring(slashIndex + 1);
        }
        if (launcher.toLowerCase().endsWith(".desktop")) {
            launcher = launcher.substring(0, launcher.length - 8);
        }
        return launcher || "application-x-executable";
    }

    function taskSnapshot(row) {
        var delegate = taskDelegateForRow(row);
        var launcher = delegate
            ? normalizedLauncherUrl(delegate.launcherTarget)
            : launcherUrlAtTaskRow(row);
        if (!launcher) {
            return null;
        }
        var appId = delegate ? String(delegate.taskAppId || "") : "";
        return {
            launcher: launcher,
            name: delegate
                ? String(delegate.originalAppName || i18n("Application"))
                : i18n("Application"),
            icon: fallbackIconName(launcher, appId),
            appId: appId
        };
    }

    function taskRowForLauncher(launcherUrl) {
        var target = normalizedLauncherUrl(launcherUrl);
        for (var row = 0; row < taskCount; ++row) {
            if (launcherUrlAtTaskRow(row) === target) {
                return row;
            }
        }
        return -1;
    }

    function groupRuntimeMembers(group) {
        void taskLayoutRevision;
        var result = [];
        if (!group || !group.members) {
            return result;
        }
        for (var index = 0; index < group.members.length; ++index) {
            var storedMember = group.members[index];
            var row = taskRowForLauncher(storedMember.launcher);
            var delegate = taskDelegateForRow(row);
            result.push({
                launcher: storedMember.launcher,
                name: delegate
                    ? String(delegate.originalAppName)
                    : storedMember.name,
                icon: delegate
                    ? delegate.originalAppIcon
                    : storedMember.icon,
                appId: delegate
                    ? String(delegate.taskAppId || "")
                    : storedMember.appId,
                running: delegate
                    ? Boolean(delegate.runningTask) : false,
                active: delegate
                    ? Boolean(delegate.taskIsActive) : false
            });
        }
        return result;
    }

    function groupPreviewItems(group) {
        return groupRuntimeMembers(group).slice(0, 4);
    }

    function groupHasRuntimeState(group, stateName) {
        var members = groupRuntimeMembers(group);
        for (var index = 0; index < members.length; ++index) {
            if (Boolean(members[index][stateName])) {
                return true;
            }
        }
        return false;
    }

    function groupProgress(group) {
        // Keep the native progress state as explicit binding dependencies.
        void progressController.appProgressState;
        void progressController.unityState;
        void progressController.appCompletionState;

        var result = {
            visible: false,
            progress: 0,
            indeterminate: false,
            completing: false
        };
        var members = groupRuntimeMembers(group);
        for (var index = 0; index < members.length; ++index) {
            var member = members[index];
            var progress = progressController.getAppProgress(
                member.appId || "", member.launcher || "");
            if (!progress.visible) {
                continue;
            }
            result.visible = true;
            result.progress = Math.max(result.progress,
                Number(progress.progress || 0));
            result.indeterminate = result.indeterminate
                || Boolean(progress.indeterminate);
            result.completing = result.completing
                || Boolean(progress.completing);
        }
        return result;
    }

    function createOrExtendAppGroup(sourceRow, targetRow) {
        var source = taskSnapshot(sourceRow);
        var target = taskSnapshot(targetRow);
        if (!source || !target || source.launcher === target.launcher) {
            return false;
        }

        var targetGroup = appGroupForLauncher(target.launcher);
        var sourceGroup = appGroupForLauncher(source.launcher);
        if (sourceGroup
                || (targetGroup && targetGroup.members.length >= 16)) {
            return false;
        }

        var nextGroups = appGroups.slice();
        if (targetGroup) {
            for (var groupIndex = 0;
                    groupIndex < nextGroups.length; ++groupIndex) {
                if (nextGroups[groupIndex].id !== targetGroup.id) {
                    continue;
                }
                var updatedMembers =
                    nextGroups[groupIndex].members.slice();
                updatedMembers.push(source);
                nextGroups[groupIndex] = {
                    version: 1,
                    id: targetGroup.id,
                    name: targetGroup.name,
                    members: updatedMembers
                };
                break;
            }
        } else {
            nextGroups.push({
                version: 1,
                id: "group-" + Date.now().toString(36)
                    + "-" + Math.floor(Math.random() * 1679616).toString(36),
                name: i18n("Group"),
                members: [target, source]
            });
        }

        if (tasksModel.launcherPosition(source.launcher) === -1) {
            tasksModel.requestAddLauncher(source.launcher);
        }
        if (tasksModel.launcherPosition(target.launcher) === -1) {
            tasksModel.requestAddLauncher(target.launcher);
        }
        saveAppGroups(nextGroups);
        return true;
    }

    function renameAppGroup(groupId, name) {
        var trimmedName = String(name || "").trim();
        if (!trimmedName) {
            return;
        }
        var nextGroups = appGroups.slice();
        for (var index = 0; index < nextGroups.length; ++index) {
            if (nextGroups[index].id !== groupId) {
                continue;
            }
            nextGroups[index] = {
                version: 1,
                id: nextGroups[index].id,
                name: trimmedName,
                members: nextGroups[index].members.slice()
            };
            saveAppGroups(nextGroups);
            return;
        }
    }

    function removeAppFromGroup(groupId, launcherUrl) {
        var targetLauncher = normalizedLauncherUrl(launcherUrl);
        var nextGroups = [];
        for (var groupIndex = 0;
                groupIndex < appGroups.length; ++groupIndex) {
            var group = appGroups[groupIndex];
            if (group.id !== groupId) {
                nextGroups.push(group);
                continue;
            }
            var remainingMembers = [];
            for (var memberIndex = 0;
                    memberIndex < group.members.length; ++memberIndex) {
                if (group.members[memberIndex].launcher
                        !== targetLauncher) {
                    remainingMembers.push(group.members[memberIndex]);
                }
            }
            if (remainingMembers.length >= 2) {
                nextGroups.push({
                    version: 1,
                    id: group.id,
                    name: group.name,
                    members: remainingMembers
                });
            }
        }
        saveAppGroups(nextGroups);
        updateActiveAppGroupPopup();
    }

    function ungroupAppGroup(groupId) {
        var nextGroups = [];
        for (var index = 0; index < appGroups.length; ++index) {
            if (appGroups[index].id !== groupId) {
                nextGroups.push(appGroups[index]);
            }
        }
        closeAppGroupPopup();
        saveAppGroups(nextGroups);
    }

    function activateGroupMember(launcherUrl) {
        var row = taskRowForLauncher(launcherUrl);
        if (row < 0) {
            return;
        }
        var index = modelIndex(row);
        activateTask(row, Boolean(taskRole(index,
            TaskManager.AbstractTasksModel.IsLauncher)));
    }

    function launchGroupMemberNewInstance(launcherUrl) {
        var row = taskRowForLauncher(launcherUrl);
        if (row >= 0) {
            launchNewInstance(row);
        }
    }

    function scheduleTaskLayoutRefresh() {
        taskLayoutRefreshTimer.restart();
    }

    property int dragOriginIndex: -1
    property int dragTargetIndex: -1
    property int dragOriginVisualIndex: -1
    property int groupDropCandidateIndex: -1
    property int groupDropTargetIndex: -1
    property real dragStartSceneMain: 0
    property real dragStartSceneCross: 0
    property real dragStartSlotCenterMain: 0
    property bool dragInOverlay: false
    property bool reorderAnimationActive: false
    readonly property bool taskDragActive: dragOriginIndex >= 0

    function moveTaskTo(row, targetRow) {
        var target = Math.max(0, Math.min(taskCount - 1, targetRow));
        if (target !== row && tasksModel.move(row, target)) {
            tasksModel.syncLaunchers();
            return true;
        }
        return false;
    }

    function moveTask(row, offset) {
        var visualIndex = stableVisualIndexForModelIndex(row);
        var targetVisualIndex = Math.max(0, Math.min(
            taskVisualCount - 1, visualIndex + offset));
        var targetRow =
            stableModelIndexForVisualIndex(targetVisualIndex);
        if (targetRow >= 0 && moveTaskTo(row, targetRow)) {
            reorderAnimationActive = true;
            reorderAnimationTimer.restart();
        }
    }

    // Keep the model stable for the whole gesture. Only the visual slots are
    // rearranged while dragging; the actual model move happens on drop. This
    // keeps the grabbed delegate under the pointer instead of replacing or
    // reindexing it whenever another icon is crossed.
    function visualIndexForModelIndex(index) {
        var stableIndex = stableVisualIndexForModelIndex(index);
        if (!taskDragActive || dragTargetIndex < 0) {
            return stableIndex;
        }
        if (stableIndex === dragOriginVisualIndex) {
            return dragTargetIndex;
        }
        if (dragTargetIndex > dragOriginVisualIndex
                && stableIndex > dragOriginVisualIndex
                && stableIndex <= dragTargetIndex) {
            return stableIndex - 1;
        }
        if (dragTargetIndex < dragOriginVisualIndex
                && stableIndex >= dragTargetIndex
                && stableIndex < dragOriginVisualIndex) {
            return stableIndex + 1;
        }
        return stableIndex;
    }

    function modelIndexForVisualIndex(index) {
        var stableIndex = index;
        if (!taskDragActive || dragTargetIndex < 0) {
            return stableModelIndexForVisualIndex(stableIndex);
        }
        if (index === dragTargetIndex) {
            stableIndex = dragOriginVisualIndex;
        } else if (dragTargetIndex > dragOriginVisualIndex
                && index >= dragOriginVisualIndex
                && index < dragTargetIndex) {
            stableIndex = index + 1;
        } else if (dragTargetIndex < dragOriginVisualIndex
                && index > dragTargetIndex
                && index <= dragOriginVisualIndex) {
            stableIndex = index - 1;
        }
        return stableModelIndexForVisualIndex(stableIndex);
    }

    function dockIndexOffset(index) {
        return desktopSwitcherLeadingExtent
            + index * (baseIconSize + itemSpacing)
            + sectionGapBeforeDockIndex(index);
    }

    function sectionGapBeforeDockIndex(index) {
        var result = 0;
        for (var breakIndex = 0;
                breakIndex < sectionBreakAfterDockIndices.length;
                ++breakIndex) {
            if (index > sectionBreakAfterDockIndices[breakIndex]) {
                result += utilitySectionGap;
            }
        }
        return result;
    }

    function hasSectionBreakAfterDockIndex(index) {
        return sectionBreakAfterDockIndices.indexOf(index) !== -1;
    }

    function baseCenterForIndex(index) {
        return mainMargin + dockIndexOffset(index) + baseIconSize / 2;
    }

    function baseSeparatorPositionAfter(index) {
        return baseCenterForIndex(index) + baseIconSize / 2
            + (itemSpacing + utilitySectionGap) / 2;
    }

    function baseDesktopSwitcherStart() {
        if (desktopSwitcherOnLeft || dockItemCount === 0) {
            return mainMargin;
        }
        return mainMargin + iconRestMainLength
            + desktopSwitcherSectionSpacing;
    }

    function baseDesktopSeparatorPosition() {
        if (!desktopSwitcherVisible || dockItemCount === 0) {
            return 0;
        }
        return desktopSwitcherOnLeft
            ? mainMargin + desktopSwitcherMainExtent
                + desktopSwitcherSectionSpacing / 2
            : mainMargin + iconRestMainLength
                + desktopSwitcherSectionSpacing / 2;
    }

    function baseIndexAtMainPosition(pos) {
        var count = taskVisualCount;
        if (count <= 0) {
            return -1;
        }
        var bestIndex = 0;
        var minDiff = Math.abs(pos
            - baseCenterForIndex(taskDockStartIndex));
        for (var i = 1; i < count; ++i) {
            var diff = Math.abs(pos
                - baseCenterForIndex(taskDockStartIndex + i));
            if (diff < minDiff) {
                minDiff = diff;
                bestIndex = i;
            }
        }
        return bestIndex;
    }

    function handleTaskDragStarted(delegate, sceneX, sceneY) {
        if (delegate.appGroupMember) {
            return;
        }
        dragOriginIndex = delegate.index;
        dragOriginVisualIndex =
            stableVisualIndexForModelIndex(delegate.index);
        dragTargetIndex = dragOriginVisualIndex;
        groupDropCandidateIndex = -1;
        groupDropTargetIndex = -1;
        groupDropHoverTimer.stop();
        dragInOverlay = delegate.inOverlay;
        dragStartSceneCross = isVertical ? sceneX : sceneY;

        overlayCloseTimer.stop();
        dockHideTimer.stop();
        if (dragInOverlay) {
            overlayOpen = true;
            dragStartSceneMain = isVertical ? sceneY : sceneX;
            dragStartSlotCenterMain =
                overlayContent.centerForModelIndex(delegate.index);
        } else {
            dragStartSceneMain = isVertical ? sceneY : sceneX;
            dragStartSlotCenterMain = baseCenterForIndex(
                taskDockStartIndex + dragOriginVisualIndex);
        }
    }

    function canGroupTaskRows(sourceRow, targetRow) {
        if (sourceRow < 0 || targetRow < 0 || sourceRow === targetRow) {
            return false;
        }
        var sourceLauncher = launcherUrlAtTaskRow(sourceRow);
        var targetLauncher = launcherUrlAtTaskRow(targetRow);
        if (!sourceLauncher || !targetLauncher
                || sourceLauncher === targetLauncher
                || appGroupForLauncher(sourceLauncher)) {
            return false;
        }
        var targetGroup = appGroupForLauncher(targetLauncher);
        return !targetGroup || targetGroup.members.length < 16;
    }

    function updateGroupDropCandidate(targetRow) {
        if (!canGroupTaskRows(dragOriginIndex, targetRow)) {
            groupDropCandidateIndex = -1;
            groupDropTargetIndex = -1;
            groupDropHoverTimer.stop();
            return;
        }
        if (groupDropCandidateIndex === targetRow) {
            return;
        }
        groupDropCandidateIndex = targetRow;
        groupDropTargetIndex = -1;
        groupDropHoverTimer.restart();
    }

    function handleTaskDragMoved(delegate, sceneX, sceneY) {
        if (!taskDragActive) {
            return;
        }

        overlayCloseTimer.stop();
        dockHideTimer.stop();

        var currentSceneMain = isVertical ? sceneY : sceneX;
        var delta = currentSceneMain - dragStartSceneMain;
        var dragTargetCenter = dragStartSlotCenterMain + delta;

        var targetIndex = dragInOverlay
            ? overlayContent.visualIndexAtMainPosition(dragTargetCenter)
            : baseIndexAtMainPosition(dragTargetCenter);

        if (targetIndex >= 0 && targetIndex < taskVisualCount
                && targetIndex !== dragTargetIndex) {
            dragTargetIndex = targetIndex;
            reorderAnimationActive = true;
            reorderAnimationTimer.restart();
        }
        var currentSceneCross = isVertical ? sceneX : sceneY;
        var targetSlotCenter = dragInOverlay
            ? overlayContent.centerForVisualIndex(
                taskDockStartIndex + targetIndex)
            : baseCenterForIndex(taskDockStartIndex + targetIndex);
        var centeredForGrouping = Math.abs(
            dragTargetCenter - targetSlotCenter)
                <= baseIconSize * 0.42
            && Math.abs(currentSceneCross - dragStartSceneCross)
                <= maximumIconSize * 0.7;
        updateGroupDropCandidate(centeredForGrouping
            ? stableModelIndexForVisualIndex(targetIndex) : -1);

        var currentSlotCenter = dragInOverlay
            ? overlayContent.centerForModelIndex(delegate.index)
            : baseCenterForIndex(taskDockStartIndex
                + visualIndexForModelIndex(delegate.index));

        var mainOffset = dragTargetCenter - currentSlotCenter;
        if (isVertical) {
            delegate.dragOffsetY = mainOffset;
            delegate.dragOffsetX = 0;
        } else {
            delegate.dragOffsetX = mainOffset;
            delegate.dragOffsetY = 0;
        }
    }

    function handleTaskDragEnded(delegate) {
        if (!taskDragActive) {
            return;
        }

        var sourceIndex = dragOriginIndex;
        var destinationIndex =
            stableModelIndexForVisualIndex(dragTargetIndex);
        var groupTargetIndex = groupDropTargetIndex;
        groupDropHoverTimer.stop();

        if (groupTargetIndex >= 0) {
            createOrExtendAppGroup(sourceIndex, groupTargetIndex);
        } else if (sourceIndex !== destinationIndex
                && destinationIndex >= 0) {
            moveTaskTo(sourceIndex, destinationIndex);
        } else {
            tasksModel.syncLaunchers();
        }

        dragOriginIndex = -1;
        dragTargetIndex = -1;
        dragOriginVisualIndex = -1;
        groupDropCandidateIndex = -1;
        groupDropTargetIndex = -1;
        reorderAnimationActive = true;
        reorderAnimationTimer.restart();
        scheduleOverlayClose();
        scheduleDockHide();
    }

    Timer {
        id: reorderAnimationTimer

        interval: 210
        repeat: false
        onTriggered: root.reorderAnimationActive = false
    }

    Timer {
        id: groupDropHoverTimer

        // Long enough to distinguish grouping from a quick reorder, short
        // enough for the target's accept animation to feel immediate.
        interval: 460
        repeat: false
        onTriggered: {
            if (root.taskDragActive
                    && root.canGroupTaskRows(root.dragOriginIndex,
                        root.groupDropCandidateIndex)) {
                root.groupDropTargetIndex =
                    root.groupDropCandidateIndex;
            }
        }
    }

    Timer {
        id: taskLayoutRefreshTimer

        interval: 0
        repeat: false
        onTriggered: ++root.taskLayoutRevision
    }

    // Nachzügler nach einem Fensterwechsel: die native Fläche eines gerade
    // sichtbar gewordenen Layer-Shell-Fensters entsteht nicht zwingend im
    // selben Ereigniszyklus. Ein zweiter Durchlauf stellt sicher, dass die
    // Minimier-Geometrie auch dann ankommt.
    Timer {
        id: geometryRepublishTimer

        interval: 150
        repeat: false
        onTriggered: root.republishTaskGeometry()
    }

    Timer {
        id: overlayCloseTimer

        interval: 250
        repeat: false
        onTriggered: {
            if (!root.baseHovered && !root.overlayHovered
                    && root.openMenuCount === 0
                    && root.openPreviewCount === 0) {
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
                    && root.openMenuCount === 0
                    && root.openPreviewCount === 0) {
                root.overlayOpen = false;
                root.revealedForMaximized = false;
            }
        }
    }

    Connections {
        target: Qt.application

        function onStateChanged(state) {
            if (state !== Qt.ApplicationActive) {
                root.closeTransientUi();
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

    onFullscreenWindowPresentChanged: {
        if (fullscreenWindowPresent) {
            closeTransientUi();
            overlayOpen = false;
            revealedForMaximized = false;
        }
    }

    onDockLocationChanged: {
        lastPointerMain = overlayWindowMainLength / 2;
        closeTransientUi();
        overlayOpen = false;
    }

    onAppGroupsChanged: {
        scheduleTaskLayoutRefresh();
        updateActiveAppGroupPopup();
    }

    onHasDockContentChanged: {
        if (!hasDockContent) {
            closeTransientUi();
            overlayOpen = false;
            revealedForMaximized = false;
        }
    }

    onDesktopCountChanged: {
        desktopCreationPending = false;
    }

    onShowFolderViewChanged: {
        if (!showFolderView) {
            closeFolderPopup();
        }
    }

    onShowTrashChanged: {
        if (!showTrash) {
            closeTransientUi();
        }
    }

    onShowPowerButtonChanged: {
        if (!showPowerButton) {
            closeTransientUi();
        }
    }

    onPowerButtonPositionChanged: {
        closeTransientUi();
        lastPointerMain = overlayWindowMainLength / 2;
        overlayOpen = false;
    }

    onConfiguredFolderUrlChanged: {
        closeFolderPopup();
        activeFolderUrl = configuredFolderUrl;
        folderModel.url = String(configuredFolderUrl);
    }

    onOverlayHoveredChanged: {
        if (folderPopup.visible && !folderPopup.hovered) {
            if (overlayHovered) {
                folderPopupCloseTimer.stop();
            } else {
                folderPopupCloseTimer.restart();
            }
        }
        if (appGroupPopup.visible && !appGroupPopup.hovered) {
            if (overlayHovered) {
                appGroupPopupCloseTimer.stop();
            } else {
                appGroupPopupCloseTimer.restart();
            }
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

        function onFolderUrlsChanged() {
            if (root.comparableFolderUrl(root.activeFolderUrl)
                    === root.comparableFolderUrl(root.configuredFolderUrl)
                    || root.containsFolderUrl(
                        Plasmoid.configuration.folderUrls || [],
                        root.activeFolderUrl)) {
                return;
            }
            root.closeFolderPopup();
            root.activeFolderUrl = root.configuredFolderUrl;
            folderModel.url = String(root.configuredFolderUrl);
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
            root.scheduleTaskLayoutRefresh();
            if (root.taskModelReady
                    && !root.sameStringList(launcherList,
                        Plasmoid.configuration.launchers)) {
                Plasmoid.configuration.launchers = launcherList;
            }
        }

        onCountChanged: root.scheduleTaskLayoutRefresh()

        Component.onCompleted: {
            launcherList = Plasmoid.configuration.launchers || [];
            root.taskModelReady = true;
            root.scheduleTaskLayoutRefresh();
        }
    }

    Connections {
        target: tasksModel

        function onDataChanged(topLeft, bottomRight, roles) {
            if (!roles || roles.length === 0
                    || roles.indexOf(
                        TaskManager.AbstractTasksModel.LauncherUrl) !== -1
                    || roles.indexOf(
                        TaskManager.AbstractTasksModel
                            .LauncherUrlWithoutIcon) !== -1) {
                root.scheduleTaskLayoutRefresh();
            }
        }

        function onModelReset() {
            root.scheduleTaskLayoutRefresh();
        }
    }

    Folder.FolderModel {
        id: folderModel

        url: String(root.configuredFolderUrl)
        sortMode: 0
        sortDesc: false
        sortDirsFirst: true
        parseDesktopFiles: true
        // File thumbnails trigger asynchronous I/O and decoding for every
        // visited directory. Theme icons keep this transient view responsive.
        previews: false
        applet: Plasmoid
    }

    Folder.FolderModel {
        id: trashModel

        url: "trash:/"
        sortMode: 0
        sortDesc: false
        sortDirsFirst: true
        applet: Plasmoid

        onListingCompleted: root.updateTrashCount()
    }

    Connections {
        target: trashModel

        function onRowsInserted() {
            root.updateTrashCount();
        }

        function onRowsRemoved() {
            root.updateTrashCount();
        }

        function onModelReset() {
            root.updateTrashCount();
        }
    }

    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
    }

    TaskManager.ActivityInfo {
        id: activityInfo
    }

    TaskManager.TasksModel {
        id: screenWindowsModel

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
        filterHidden: true

        onCountChanged: root.scheduleScreenWindowStateUpdate()
        Component.onCompleted:
            root.scheduleScreenWindowStateUpdate()
    }

    Connections {
        target: screenWindowsModel

        function onDataChanged() {
            root.scheduleScreenWindowStateUpdate();
        }

        function onModelReset() {
            root.scheduleScreenWindowStateUpdate();
        }

        function onRowsInserted() {
            root.scheduleScreenWindowStateUpdate();
        }

        function onRowsRemoved() {
            root.scheduleScreenWindowStateUpdate();
        }
    }

    component TrackedMenu: QQC2.Menu {
        id: trackedMenu

        property bool countedAsOpen: false

        closePolicy: QQC2.Popup.CloseOnEscape
            | QQC2.Popup.CloseOnPressOutside
            | QQC2.Popup.CloseOnReleaseOutside
            | QQC2.Popup.CloseOnPressOutsideParent
            | QQC2.Popup.CloseOnReleaseOutsideParent

        Component.onCompleted: root.configureContextMenu(trackedMenu)

        onOpened: {
            if (!countedAsOpen) {
                countedAsOpen = true;
                root.menuOpened(trackedMenu);
            }
        }
        onClosed: {
            if (countedAsOpen) {
                countedAsOpen = false;
                root.menuClosed(trackedMenu);
            }
        }
        Component.onDestruction: {
            if (countedAsOpen) {
                root.menuClosed(trackedMenu);
            }
        }
    }

    component TaskDelegate: DockItem {
        id: taskDelegate

        required property int index
        required property var model
        property real displayScale: 1.0
        property real displayCrossExtent: root.baseIconSize
        readonly property string originalAppName:
            String(model.AppName || model.display || i18n("Application"))
        readonly property var originalAppIcon:
            model.decoration || "application-x-executable"
        readonly property string taskAppId: String(model.AppId || "")

        readonly property bool launcherOnly: Boolean(model.IsLauncher)
        readonly property bool runningTask: !launcherOnly
            && (Boolean(model.IsWindow)
                || Boolean(model.IsStartup)
                || Boolean(model.IsGroupParent))
        readonly property bool groupParent: Boolean(model.IsGroupParent)
        readonly property int childCount: Number(model.ChildCount)
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
        readonly property bool taskIsActive:
            runningTask && Boolean(model.IsActive)
        readonly property var appGroup:
            root.appGroupForTask(index, launcherTarget)
        readonly property bool appGroupMember: Boolean(appGroup)
        readonly property bool appGroupLeader: appGroupMember
            && root.isAppGroupLeaderTask(index, appGroup.id)
        readonly property bool hiddenAppGroupMember:
            appGroupMember && !appGroupLeader
        readonly property var appGroupPreviewItems: {
            void root.taskLayoutRevision;
            return appGroupLeader
                ? root.groupPreviewItems(appGroup) : [];
        }

        appName: appGroupLeader ? appGroup.name : originalAppName
        appIcon: originalAppIcon
        baseSize: root.baseIconSize
        currentScale: displayScale
        crossIconExtent: displayCrossExtent
        isVertical: root.isVertical
        location: root.dockLocation
        screenEdgeMargin: root.panelEdgeMargin
        isRunning: appGroupLeader
            ? root.groupHasRuntimeState(appGroup, "running")
            : runningTask
        isActive: appGroupLeader
            ? root.groupHasRuntimeState(appGroup, "active")
            : taskIsActive
        isStarting: Boolean(model.IsStartup)
        launchAnimation: root.launchAnimation
        isAppGroup: appGroupLeader
        groupPreviewItems: appGroupPreviewItems
        dragEnabled: !appGroupMember
        enabled: !hiddenAppGroupMember
        opacity: hiddenAppGroupMember ? 0 : 1
        dropTarget: root.groupDropTargetIndex === index

        Behavior on opacity {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

        readonly property var progressInfo: root.showProgressIndicators
            ? (appGroupLeader
                ? root.groupProgress(appGroup)
                : progressController.getAppProgress(
                    model.AppId || "",
                    model.LauncherUrlWithoutIcon || model.LauncherUrl || ""))
            : ({
                visible: false,
                progress: 0.0,
                indeterminate: false,
                completing: false
            })

        progressVisible: Boolean(progressInfo.visible)
        progressValue: Number(progressInfo.progress)
        progressIndeterminate: Boolean(progressInfo.indeterminate)
        progressCompleting: Boolean(progressInfo.completing)

        readonly property var recentShareInfo: {
            // Establish the property dependency explicitly. The native lookup
            // function itself cannot make a QML binding observe its data.
            if (root.recentKdeConnectShares === undefined
                    || taskDelegate.appGroupMember
                    || !root.showKdeConnectRecentShares
                    || !kdeConnectMonitor.active) {
                return null;
            }
            return kdeConnectMonitor.getLatestShareForApp(
                model.AppId || "",
                model.LauncherUrlWithoutIcon || model.LauncherUrl || "");
        }

        hasRecentShare: Boolean(recentShareInfo && recentShareInfo.url)
        recentShareDevice: recentShareInfo ? String(recentShareInfo.deviceName || "") : ""
        recentShareUrl: recentShareInfo ? String(recentShareInfo.url || "") : ""
        recentSharePreview: recentShareInfo ? String(recentShareInfo.preview || "") : ""
        onRecentShareClicked: {
            if (recentShareInfo && recentShareInfo.url) {
                kdeConnectMonitor.openShareUrl(recentShareInfo.url);
            }
        }

        Behavior on currentScale {
            NumberAnimation {
                duration: 75
                easing.type: Easing.OutCubic
            }
        }

        Behavior on x {
            enabled: (root.taskDragActive || root.reorderAnimationActive)
                && !taskDelegate.isDragging
            NumberAnimation {
                duration: 145
                easing.type: Easing.OutCubic
            }
        }

        Behavior on y {
            enabled: (root.taskDragActive || root.reorderAnimationActive)
                && !taskDelegate.isDragging
            NumberAnimation {
                duration: 145
                easing.type: Easing.OutCubic
            }
        }

        property bool inOverlay: false
        property bool previewCountedAsOpen: false
        property bool geometryPublishPending: false

        previewAvailable: !appGroupMember && runningTask
        windowsList: (!appGroupMember && runningTask
                && (previewDataRequested || previewOpen))
            ? root.windowsInfoForTask(index, childCount) : []

        function publishGeometry() {
            geometryPublishPending = false;
            var owningWindow = taskDelegate.Window.window;
            if (runningTask && owningWindow && owningWindow.visible) {
                root.publishDelegateGeometry(index, taskDelegate, owningWindow);
            }
        }

        function scheduleGeometryPublish() {
            // Layer-shell visibility and delegate geometry can settle later in
            // the same event cycle. Queue first, then let publishGeometry()
            // select the delegate that is actually visible.
            if (geometryPublishPending) {
                return;
            }
            geometryPublishPending = true;
            Qt.callLater(publishGeometry);
        }

        onXChanged: scheduleGeometryPublish()
        onYChanged: scheduleGeometryPublish()
        onWidthChanged: scheduleGeometryPublish()
        onHeightChanged: scheduleGeometryPublish()
        onDisplayScaleChanged: scheduleGeometryPublish()
        onRunningTaskChanged: {
            scheduleGeometryPublish();
        }
        onChildCountChanged: scheduleGeometryPublish()
        Component.onCompleted: {
            scheduleGeometryPublish();
            root.scheduleTaskLayoutRefresh();
        }
        Component.onDestruction: {
            if (previewCountedAsOpen) {
                previewCountedAsOpen = false;
                root.previewClosed();
            }
        }

        Connections {
            target: taskDelegate.Window.window

            function onVisibleChanged() {
                taskDelegate.scheduleGeometryPublish();
            }

            function onXChanged() {
                taskDelegate.scheduleGeometryPublish();
            }

            function onYChanged() {
                taskDelegate.scheduleGeometryPublish();
            }

            function onScreenChanged() {
                taskDelegate.scheduleGeometryPublish();
            }
        }

        Connections {
            target: root

            function onDockRevealProgressChanged() {
                taskDelegate.scheduleGeometryPublish();
            }
        }

        onClicked: {
            if (appGroupLeader) {
                var popupParent = taskDelegate;
                if (!inOverlay) {
                    var overlayGroup = overlayRepeater.itemAt(index);
                    if (overlayGroup) {
                        popupParent = overlayGroup;
                    }
                }
                root.toggleAppGroupPopup(appGroup.id, popupParent);
            } else {
                triggerBounce();
                root.activateTask(index, launcherOnly);
            }
        }

        onNewInstanceRequested: {
            if (!appGroupMember) {
                triggerBounce();
                root.launchNewInstance(index);
            }
        }

        onContextMenuRequested: {
            if (appGroupLeader) {
                appGroupMenu.popup();
            } else {
                taskMenu.popup();
            }
        }
        onDragStarted: (sx, sy) => root.handleTaskDragStarted(taskDelegate, sx, sy)
        onDragMoved: (sx, sy) => root.handleTaskDragMoved(taskDelegate, sx, sy)
        onDragEnded: root.handleTaskDragEnded(taskDelegate)
        onWindowActivated: (modelIdx) => {
            if (modelIdx && modelIdx.valid) {
                tasksModel.requestActivate(modelIdx);
            }
        }
        onWindowClosed: (modelIdx) => {
            if (modelIdx && modelIdx.valid) {
                tasksModel.requestClose(modelIdx);
            }
        }
        onPreviewVisibilityChanged: (visible) => {
            if (visible && !previewCountedAsOpen) {
                previewCountedAsOpen = true;
                root.previewOpened();
            } else if (!visible && previewCountedAsOpen) {
                previewCountedAsOpen = false;
                root.previewClosed();
            }
        }

        TrackedMenu {
            id: taskMenu

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

            QQC2.MenuItem {
                text: taskDelegate.hasRecentShare
                    ? i18n("Open again from %1", taskDelegate.recentShareDevice)
                    : ""
                icon.name: "preferences-kde-connect"
                visible: taskDelegate.hasRecentShare && taskDelegate.recentShareUrl.length > 0
                onTriggered: {
                    if (taskDelegate.recentShareUrl.length > 0) {
                        kdeConnectMonitor.openShareUrl(taskDelegate.recentShareUrl);
                    }
                }
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
                enabled: root.stableVisualIndexForModelIndex(
                    taskDelegate.index) > 0
                onTriggered: root.moveTask(taskDelegate.index, -1)
            }

            QQC2.MenuItem {
                text: root.isVertical ? i18n("Move Down") : i18n("Move Right")
                icon.name: root.isVertical ? "go-down" : "go-next"
                visible: taskDelegate.pinned
                enabled: root.stableVisualIndexForModelIndex(
                    taskDelegate.index) < root.taskVisualCount - 1
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

        TrackedMenu {
            id: appGroupMenu

            QQC2.MenuItem {
                text: i18n("Open Group")
                icon.name: "folder-open"
                onTriggered: root.toggleAppGroupPopup(
                    taskDelegate.appGroup.id, taskDelegate)
            }

            QQC2.MenuItem {
                text: i18n("Ungroup")
                icon.name: "edit-delete"
                onTriggered: root.ungroupAppGroup(
                    taskDelegate.appGroup.id)
            }
        }
    }

    component DesktopSwitcher: Item {
        id: desktopSwitcher

        readonly property real crossExtent: root.baseIconSize

        width: root.isVertical
            ? crossExtent : root.desktopSwitcherMainExtent
        height: root.isVertical
            ? root.desktopSwitcherMainExtent : crossExtent

        Repeater {
            model: root.desktopCount

            delegate: Item {
                id: desktopButton

                required property int index

                readonly property bool active:
                    root.isDesktopActive(index)
                readonly property string desktopName:
                    root.desktopNameAt(index)
                readonly property string label:
                    root.desktopLabelAt(index)
                readonly property real mainExtent:
                    root.desktopButtonMainExtent(index)
                readonly property real compactCrossExtent:
                    root.desktopSwitcherLabelMode === 0
                        ? Math.min(desktopSwitcher.crossExtent, 30)
                        : desktopSwitcher.crossExtent

                x: root.isVertical ? 0
                    : root.desktopButtonMainStart(index)
                y: root.isVertical
                    ? root.desktopButtonMainStart(index) : 0
                width: root.isVertical
                    ? desktopSwitcher.crossExtent : mainExtent
                height: root.isVertical
                    ? mainExtent : desktopSwitcher.crossExtent
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: desktopName
                Accessible.description: active
                    ? i18n("Current desktop") : i18n("Switch desktop")
                Accessible.onPressAction: root.activateDesktop(index)

                Rectangle {
                    id: desktopButtonSurface

                    x: root.isVertical
                        ? (parent.width - width) / 2 : 0
                    y: root.isVertical
                        ? 0 : (parent.height - height) / 2
                    width: root.isVertical
                        ? desktopButton.compactCrossExtent : parent.width
                    height: root.isVertical
                        ? parent.height : desktopButton.compactCrossExtent
                    radius: Math.min(9, Math.min(width, height) / 2)
                    color: {
                        var reference = desktopButton.active
                            ? Kirigami.Theme.highlightColor
                            : Kirigami.Theme.alternateBackgroundColor;
                        var alpha = desktopButton.active ? 0.9
                            : (desktopButtonHover.hovered ? 0.72 : 0.48);
                        return Qt.rgba(reference.r, reference.g,
                            reference.b, alpha);
                    }
                    border.width: desktopButton.active ? 1 : 0
                    border.color: Kirigami.Theme.highlightedTextColor

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    QQC2.Label {
                        readonly property bool rotatedDesktopName:
                            root.isVertical
                                && root.desktopSwitcherLabelMode === 1

                        anchors.centerIn: parent
                        width: rotatedDesktopName
                            ? Math.max(0, parent.height - 14)
                            : Math.max(0, parent.width - 14)
                        height: rotatedDesktopName
                            ? parent.width : parent.height
                        rotation: rotatedDesktopName
                            ? (root.dockLocation
                                === PlasmaCore.Types.LeftEdge ? -90 : 90)
                            : 0
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: desktopButton.label
                        color: desktopButton.active
                            ? Kirigami.Theme.highlightedTextColor
                            : Kirigami.Theme.textColor
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                }

                HoverHandler {
                    id: desktopButtonHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.activateDesktop(desktopButton.index)
                }

                Keys.onReturnPressed:
                    root.activateDesktop(desktopButton.index)
                Keys.onEnterPressed:
                    root.activateDesktop(desktopButton.index)
                Keys.onSpacePressed:
                    root.activateDesktop(desktopButton.index)

                QQC2.ToolTip.visible: desktopButtonHover.hovered
                QQC2.ToolTip.text: desktopButton.desktopName
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        Item {
            id: addDesktopButton

            visible: root.desktopAddButtonVisible
            x: root.isVertical ? 0
                : root.desktopButtonMainStart(root.desktopCount)
            y: root.isVertical
                ? root.desktopButtonMainStart(root.desktopCount) : 0
            width: root.isVertical
                ? desktopSwitcher.crossExtent
                : root.desktopAddButtonMainExtent
            height: root.isVertical
                ? root.desktopAddButtonMainExtent
                : desktopSwitcher.crossExtent
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: i18n("Add desktop")
            Accessible.onPressAction: root.createDesktop()

            Rectangle {
                x: root.isVertical ? (parent.width - width) / 2 : 0
                y: root.isVertical ? 0 : (parent.height - height) / 2
                width: root.isVertical
                    ? Math.min(desktopSwitcher.crossExtent, 30)
                    : parent.width
                height: root.isVertical
                    ? parent.height
                    : Math.min(desktopSwitcher.crossExtent, 30)
                radius: Math.min(9, Math.min(width, height) / 2)
                color: {
                    var reference = Kirigami.Theme.alternateBackgroundColor;
                    var alpha = addDesktopHover.hovered ? 0.72 : 0.48;
                    return Qt.rgba(reference.r, reference.g,
                        reference.b, alpha);
                }

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                QQC2.Label {
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "+"
                    color: Kirigami.Theme.textColor
                    font.pixelSize: 20
                    font.weight: Font.Medium
                }
            }

            HoverHandler {
                id: addDesktopHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.createDesktop()
            }

            Keys.onReturnPressed: root.createDesktop()
            Keys.onEnterPressed: root.createDesktop()
            Keys.onSpacePressed: root.createDesktop()

            QQC2.ToolTip.visible: addDesktopHover.hovered
            QQC2.ToolTip.text: i18n("Add desktop")
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
    }

    component FolderDropTarget: DropArea {
        id: folderDropTarget

        property var excludedItems: []
        property bool dragContainsFolder: false

        function overExcludedItem(x, y) {
            for (var index = 0; index < excludedItems.length; ++index) {
                var item = excludedItems[index];
                if (!item || !item.visible) {
                    continue;
                }
                var topLeft = item.mapToItem(folderDropTarget, 0, 0);
                if (x >= topLeft.x && x <= topLeft.x + item.width
                        && y >= topLeft.y && y <= topLeft.y + item.height) {
                    return true;
                }
            }
            return false;
        }

        onEntered: (drag) => {
            dragContainsFolder = root.droppedUrlsContainFolder(drag.urls);
            var accepted = !overExcludedItem(drag.x, drag.y)
                && dragContainsFolder;
            drag.accepted = accepted;
            root.folderDropActive = accepted;
            if (accepted) {
                root.revealDock();
                root.overlayOpen = true;
                dockHideTimer.stop();
            }
        }
        onPositionChanged: (drag) => {
            var accepted = !overExcludedItem(drag.x, drag.y)
                && dragContainsFolder;
            drag.accepted = accepted;
            root.folderDropActive = accepted;
            if (accepted) {
                root.revealDock();
                dockHideTimer.stop();
            }
        }
        onExited: {
            dragContainsFolder = false;
            root.folderDropActive = false;
            root.scheduleOverlayClose();
            root.scheduleDockHide();
        }
        onDropped: (drop) => {
            var accepted = !overExcludedItem(drop.x, drop.y)
                && root.addDroppedFolders(drop.urls);
            root.folderDropActive = false;
            dragContainsFolder = false;
            if (accepted) {
                drop.acceptProposedAction();
            } else {
                drop.accepted = false;
            }
        }
    }

    component AuxiliaryDelegate: DockItem {
        required property int dockIndex
        property real displayScale: 1.0
        property real displayCrossExtent: root.baseIconSize

        baseSize: root.baseIconSize
        currentScale: displayScale
        crossIconExtent: displayCrossExtent
        isVertical: root.isVertical
        location: root.dockLocation
        screenEdgeMargin: root.panelEdgeMargin
        launchAnimation: root.launchAnimation
        dragEnabled: false

        Behavior on currentScale {
            NumberAnimation {
                duration: 75
                easing.type: Easing.OutCubic
            }
        }
    }

    component UtilityDelegate: AuxiliaryDelegate {
        id: utilityDelegate

        required property string utilityType
        property int folderIndex: -1
        property url folderUrl: ""
        property bool inOverlay: false

        readonly property bool isFolder: utilityType === "folder"
        readonly property bool isTrash: utilityType === "trash"

        readonly property var folderProgressInfo: (root.showProgressIndicators && isFolder)
            ? progressController.getFolderProgress(folderUrl)
            : ({
                visible: false,
                progress: 0.0,
                indeterminate: false,
                completing: false
            })

        readonly property var recentFolderShareInfo: {
            if (root.recentKdeConnectShares === undefined
                    || !root.showKdeConnectRecentShares
                    || !kdeConnectMonitor.active
                    || !utilityDelegate.isFolder) {
                return null;
            }
            return kdeConnectMonitor.getLatestShareForFolder(
                utilityDelegate.folderUrl);
        }

        progressVisible: Boolean(folderProgressInfo.visible)
        progressValue: Number(folderProgressInfo.progress)
        progressIndeterminate: Boolean(folderProgressInfo.indeterminate)
        progressCompleting: Boolean(folderProgressInfo.completing)
        hasRecentShare: Boolean(recentFolderShareInfo
            && recentFolderShareInfo.url)
        recentShareDevice: recentFolderShareInfo
            ? String(recentFolderShareInfo.deviceName || "") : ""
        recentShareUrl: recentFolderShareInfo
            ? String(recentFolderShareInfo.url || "") : ""
        recentSharePreview: recentFolderShareInfo
            ? String(recentFolderShareInfo.preview || "") : ""
        onRecentShareClicked: {
            if (recentFolderShareInfo && recentFolderShareInfo.url) {
                kdeConnectMonitor.openShareUrl(recentFolderShareInfo.url);
            }
        }

        appName: isFolder
            ? root.folderName(folderUrl)
            : (isTrash ? i18n("Trash") : "")
        appIcon: {
            if (isFolder) {
                return root.folderIconName(folderUrl);
            }
            if (!isTrash) {
                return "application-x-executable";
            }
            if (root.isVolumeDragOverTrash) {
                return "media-eject";
            }
            // KIO exposes trash:/ as a folder on some Plasma versions.
            // Resolve the canonical trash icon names through the active icon
            // theme instead, while still reflecting the empty/full state.
            return root.trashItemCount > 0
                ? "user-trash-full" : "user-trash";
        }
        onClicked: {
            if (isFolder) {
                var popupParent = utilityDelegate;
                if (!inOverlay) {
                    var overlayFolder = folderOverlayRepeater.itemAt(folderIndex);
                    if (overlayFolder) {
                        popupParent = overlayFolder;
                    }
                }
                root.toggleFolderPopup(folderUrl, popupParent);
            } else if (isTrash) {
                triggerBounce();
                root.openTrashExternally();
            }
        }
        onContextMenuRequested: utilityMenu.popup()

        DropArea {
            anchors.fill: parent
            enabled: utilityDelegate.isTrash

            onEntered: (drag) => {
                if (drag.keys && drag.keys.indexOf("org.kde.plasma.macosdock.removable-volume") !== -1) {
                    root.isVolumeDragOverTrash = true;
                }
                utilityDelegate.dropTarget = true;
            }
            onExited: {
                root.isVolumeDragOverTrash = false;
                utilityDelegate.dropTarget = false;
            }
            onDropped: (drop) => {
                root.isVolumeDragOverTrash = false;
                utilityDelegate.dropTarget = false;
                if (drop.keys && drop.keys.indexOf("org.kde.plasma.macosdock.removable-volume") !== -1) {
                    var udi = drop.source
                        ? String(drop.source.objectName || "") : "";
                    if (udi) {
                        removableVolumesModel.remove(udi);
                        drop.acceptProposedAction();
                    }
                } else if (utilityDelegate.isTrash) {
                    trashModel.drop(utilityDelegate, drop, -1, false);
                }
            }
        }

        TrackedMenu {
            id: utilityMenu

            QQC2.MenuItem {
                text: utilityDelegate.isFolder
                    ? i18n("Open Folder") : i18n("Open Trash")
                icon.name: utilityDelegate.isFolder
                    ? "document-open-folder" : "user-trash"
                onTriggered: {
                    if (utilityDelegate.isFolder) {
                        root.openFolderExternally(utilityDelegate.folderUrl);
                    } else {
                        root.openTrashExternally();
                    }
                }
            }

            QQC2.MenuItem {
                text: utilityDelegate.hasRecentShare
                    ? i18n("Open again from %1",
                        utilityDelegate.recentShareDevice)
                    : ""
                icon.name: "preferences-kde-connect"
                visible: utilityDelegate.hasRecentShare
                    && utilityDelegate.recentShareUrl.length > 0
                onTriggered: kdeConnectMonitor.openShareUrl(
                    utilityDelegate.recentShareUrl)
            }

            QQC2.MenuItem {
                visible: utilityDelegate.isFolder
                    && utilityDelegate.folderIndex > 0
                text: i18n("Remove Folder from Dock")
                icon.name: "list-remove"
                onTriggered: root.removeAdditionalFolder(
                    utilityDelegate.folderUrl)
            }

            QQC2.MenuItem {
                visible: utilityDelegate.isTrash
                text: i18n("Empty Trash")
                icon.name: "trash-empty"
                enabled: root.trashItemCount > 0
                onTriggered: root.emptyTrash()
            }
        }
    }

    component PowerDelegate: AuxiliaryDelegate {
        appName: i18n("Power / Session")
        appIcon: "system-shutdown"

        onClicked: powerMenu.popup()
        onContextMenuRequested: powerMenu.popup()

        TrackedMenu {
            id: powerMenu

            QQC2.MenuItem {
                text: i18n("Sleep / Standby")
                icon.name: "system-suspend"
                enabled: sessionManagement.canSuspend
                onTriggered: sessionManagement.suspend()
            }

            QQC2.MenuItem {
                text: i18n("Restart…")
                icon.name: "system-reboot"
                enabled: sessionManagement.canReboot
                onTriggered: sessionManagement.requestReboot(
                    Sessions.SessionManagement.ForcePrompt)
            }

            QQC2.MenuItem {
                text: i18n("Shut Down…")
                icon.name: "system-shutdown"
                enabled: sessionManagement.canShutdown
                onTriggered: sessionManagement.requestShutdown(
                    Sessions.SessionManagement.ForcePrompt)
            }

            QQC2.MenuSeparator {}

            QQC2.MenuItem {
                text: i18n("Lock Screen")
                icon.name: "system-lock-screen"
                enabled: sessionManagement.canLock
                onTriggered: sessionManagement.lock()
            }

            QQC2.MenuItem {
                text: i18n("Log Out…")
                icon.name: "system-log-out"
                enabled: sessionManagement.canLogout
                onTriggered: sessionManagement.requestLogout(
                    Sessions.SessionManagement.ForcePrompt)
            }
        }
    }

    component RemovableVolumeDelegate: AuxiliaryDelegate {
        id: volumeDelegate

        required property string volumeUdi
        required property string volumeDisplayName
        required property string volumeIconName
        required property bool volumeMounted
        required property bool volumeBusy
        required property string volumeOperation
        required property string volumeKind
        required property bool volumeCanOpen
        required property bool volumeCanRemove
        required property string volumeErrorText

        appName: volumeDisplayName
        appIcon: volumeIconName.length > 0 ? volumeIconName : "drive-removable-media"

        opacity: volumeMounted ? 1.0 : 0.25
        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
        }

        progressVisible: volumeBusy
        progressIndeterminate: volumeBusy

        onClicked: {
            if (volumeBusy) {
                return;
            }
            triggerBounce();
            // open() handles mount-if-needed internally
            removableVolumesModel.open(volumeUdi);
        }
        onContextMenuRequested: volumeMenu.popup()

        onVolumeErrorTextChanged: {
            if (volumeErrorText.length > 0) {
                errorToolTip.show(volumeErrorText, 5000);
            }
        }

        QQC2.ToolTip {
            id: errorToolTip
            timeout: 5000
        }

        Item {
            id: dragProxy
            objectName: volumeDelegate.volumeUdi
            width: volumeDelegate.width
            height: volumeDelegate.height
            Drag.hotSpot: Qt.point(width / 2, height / 2)
            Drag.keys: ["org.kde.plasma.macosdock.removable-volume"]
            Drag.proposedAction: Qt.MoveAction
            Drag.source: dragProxy
            Drag.supportedActions: Qt.MoveAction
        }

        DragHandler {
            id: volumeDragHandler
            enabled: volumeDelegate.volumeMounted
                && volumeDelegate.volumeCanRemove
                && !volumeDelegate.volumeBusy
            target: dragProxy
            onActiveChanged: {
                if (active) {
                    dragProxy.Drag.start(Qt.MoveAction);
                } else {
                    dragProxy.Drag.drop();
                    dragProxy.x = 0;
                    dragProxy.y = 0;
                }
            }
        }

        TrackedMenu {
            id: volumeMenu

            QQC2.MenuItem {
                text: volumeDelegate.volumeMounted
                    ? i18n("Open Volume")
                    : (volumeDelegate.volumeOperation === "mounting"
                        ? i18n("Mounting…")
                        : i18n("Mount Volume"))
                icon.name: volumeDelegate.volumeMounted
                    ? "document-open-folder" : "media-mount"
                enabled: !volumeDelegate.volumeBusy
                onTriggered: removableVolumesModel.open(volumeDelegate.volumeUdi)
            }

            QQC2.MenuItem {
                text: volumeDelegate.volumeOperation === "ejecting"
                    ? i18n("Ejecting…")
                    : (volumeDelegate.volumeOperation === "unmounting"
                        ? i18n("Unmounting…")
                        : (volumeDelegate.volumeKind === "optical"
                            ? i18n("Eject Disc")
                            : i18n("Unmount Volume")))
                icon.name: "media-eject"
                enabled: volumeDelegate.volumeMounted
                    && volumeDelegate.volumeCanRemove
                    && !volumeDelegate.volumeBusy
                onTriggered: removableVolumesModel.remove(volumeDelegate.volumeUdi)
            }
        }
    }

    fullRepresentation: Item {
        id: hostAnchor

        Layout.minimumWidth: 1
        Layout.minimumHeight: 1
        Layout.preferredWidth: 1
        Layout.preferredHeight: 1
        Layout.maximumWidth: 1
        Layout.maximumHeight: 1
        Layout.fillWidth: false
        Layout.fillHeight: false

        width: 1
        height: 1
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

    FolderPopup {
        id: folderPopup

        folderModel: folderModel
        rootFolderUrl: root.activeFolderUrl
        location: root.dockLocation
        screenEdgeMargin: root.panelEdgeMargin
        surfaceOpacity: Math.min(0.94, root.backgroundOpacity + 0.18)
        useThemeColor: root.useThemeBackground
        customColor: root.customBackgroundColor
        requestedRadius: Math.max(16, root.cornerRadius)
        borderOpacity: root.borderOpacity
        shadowOpacity: root.shadowOpacity
        showHighlight: root.showHighlight
        blurEnabled: root.enableBlur
        viewMode: root.folderViewMode

        onViewModeRequested: (mode) => {
            if (Plasmoid.configuration.folderViewMode !== mode) {
                Plasmoid.configuration.folderViewMode = mode;
            }
        }

        onOpenFolderRequested: (folderUrl) =>
            Folder.AppLauncher.openUrl(folderUrl)

        onVisibleChanged: {
            if (visible && !root.folderPopupCountedAsOpen) {
                root.folderPopupCountedAsOpen = true;
                root.previewOpened();
            } else if (!visible && root.folderPopupCountedAsOpen) {
                root.folderPopupCountedAsOpen = false;
                root.previewClosed();
                folderModel.url = String(root.activeFolderUrl);
            }
        }

        onHoveredChanged: {
            if (hovered) {
                folderPopupCloseTimer.stop();
            } else {
                folderPopupCloseTimer.restart();
            }
        }
    }

    Timer {
        id: folderPopupCloseTimer

        interval: 380
        repeat: false
        onTriggered: {
            if (folderPopup.visible && !folderPopup.hovered
                    && !root.overlayHovered) {
                folderPopup.close();
            }
        }
    }

    AppGroupPopup {
        id: appGroupPopup

        location: root.dockLocation
        screenEdgeMargin: root.panelEdgeMargin
        surfaceOpacity: Math.min(0.94, root.backgroundOpacity + 0.2)
        useThemeColor: root.useThemeBackground
        customColor: root.customBackgroundColor
        requestedRadius: Math.max(17, root.cornerRadius)
        borderOpacity: root.borderOpacity
        shadowOpacity: root.shadowOpacity
        showHighlight: root.showHighlight
        blurEnabled: root.enableBlur

        onMemberActivated: (launcherUrl) => {
            root.closeAppGroupPopup();
            root.activateGroupMember(launcherUrl);
        }
        onMemberNewInstanceRequested: (launcherUrl) => {
            root.closeAppGroupPopup();
            root.launchGroupMemberNewInstance(launcherUrl);
        }
        onMemberRemoved: (launcherUrl) =>
            root.removeAppFromGroup(groupId, launcherUrl)
        onGroupNameRequested: (name) =>
            root.renameAppGroup(groupId, name)
        onUngroupRequested: root.ungroupAppGroup(groupId)

        onVisibleChanged: {
            if (visible && !root.appGroupPopupCountedAsOpen) {
                root.appGroupPopupCountedAsOpen = true;
                root.previewOpened();
            } else if (!visible
                    && root.appGroupPopupCountedAsOpen) {
                root.appGroupPopupCountedAsOpen = false;
                root.previewClosed();
            }
        }

        onHoveredChanged: {
            if (hovered) {
                appGroupPopupCloseTimer.stop();
            } else {
                appGroupPopupCloseTimer.restart();
            }
        }
    }

    Timer {
        id: appGroupPopupCloseTimer

        interval: 480
        repeat: false
        onTriggered: {
            if (appGroupPopup.visible && !appGroupPopup.hovered
                    && !root.overlayHovered) {
                appGroupPopup.hidePopup();
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
        // A Dock belongs above regular windows, but below true fullscreen
        // surfaces. LayerOverlay is reserved for OSD-style UI and otherwise
        // forces the Dock over fullscreen video in mpv and Dragon Player.
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.keyboardInteractivity:
            LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.activateOnShow: false
        LayerShell.Window.wantsToBeOnActiveScreen: true

        onVisibleChanged: {
            if (!visible) {
                root.baseHovered = false;
            }
            root.republishTaskGeometry();
            geometryRepublishTimer.restart();
        }

        Item {
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

            FolderDropTarget {
                anchors.fill: parent
                z: 1
                excludedItems: [trashBaseItem, powerBaseItem]
            }

            Rectangle {
                anchors.fill: parent
                z: 9998
                visible: root.folderDropActive
                color: "transparent"
                radius: root.cornerRadius
                border.width: 2
                border.color: Kirigami.Theme.highlightColor
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
                model: root.sectionBreakAfterDockIndices

                delegate: Rectangle {
                    required property int modelData

                    color: Kirigami.Theme.textColor
                    opacity: 0.24
                    radius: 1
                    width: root.isVertical
                        ? root.baseIconSize * 0.62 : 1
                    height: root.isVertical
                        ? 1 : root.baseIconSize * 0.62
                    x: root.isVertical
                        ? root.crossMargin
                            + (root.baseIconSize - width) / 2
                        : root.baseSeparatorPositionAfter(modelData)
                            - width / 2
                    y: root.isVertical
                        ? root.baseSeparatorPositionAfter(modelData)
                            - height / 2
                        : root.crossMargin
                            + (root.baseIconSize - height) / 2
                }
            }

            Rectangle {
                visible: root.desktopSwitcherVisible
                    && root.dockItemCount > 0
                color: Kirigami.Theme.textColor
                opacity: 0.24
                radius: 1
                width: root.isVertical
                    ? root.baseIconSize * 0.62 : 1
                height: root.isVertical
                    ? 1 : root.baseIconSize * 0.62
                x: root.isVertical
                    ? root.crossMargin
                        + (root.baseIconSize - width) / 2
                    : root.baseDesktopSeparatorPosition() - width / 2
                y: root.isVertical
                    ? root.baseDesktopSeparatorPosition() - height / 2
                    : root.crossMargin
                        + (root.baseIconSize - height) / 2
            }

            DesktopSwitcher {
                visible: root.desktopSwitcherVisible
                x: root.isVertical ? root.crossMargin
                    : root.baseDesktopSwitcherStart()
                y: root.isVertical
                    ? root.baseDesktopSwitcherStart() : root.crossMargin
            }

            Repeater {
                id: baseRepeater

                model: tasksModel

                delegate: TaskDelegate {
                    displayScale: 1.0
                    displayCrossExtent: root.baseIconSize
                    x: root.isVertical ? root.crossMargin
                        : root.baseCenterForIndex(
                            root.taskDockStartIndex
                                + root.visualIndexForModelIndex(index))
                            - scaledSize / 2
                    y: root.isVertical
                        ? root.baseCenterForIndex(
                            root.taskDockStartIndex
                                + root.visualIndexForModelIndex(index))
                            - scaledSize / 2
                        : root.crossMargin
                }
            }

            Repeater {
                model: root.folderItemCount

                delegate: UtilityDelegate {
                    required property int index

                    folderIndex: index
                    folderUrl: root.folderUrlAt(index)
                    dockIndex: root.folderDockIndex + index
                    utilityType: "folder"
                    x: root.isVertical ? root.crossMargin
                        : root.baseCenterForIndex(dockIndex)
                            - scaledSize / 2
                    y: root.isVertical
                        ? root.baseCenterForIndex(dockIndex)
                            - scaledSize / 2
                        : root.crossMargin
                }
            }

            Repeater {
                model: root.showRemovableVolumes ? removableVolumesModel : 0

                delegate: RemovableVolumeDelegate {
                    required property int index
                    required property string udi
                    required property string displayName
                    required property string iconName
                    required property string kind
                    required property string errorText
                    required property bool canOpen
                    required property bool canRemove
                    required property bool mounted
                    required property bool busy
                    required property string operation

                    volumeUdi: udi
                    volumeDisplayName: displayName
                    volumeIconName: iconName
                    volumeKind: kind
                    volumeCanOpen: canOpen
                    volumeCanRemove: canRemove
                    volumeErrorText: errorText
                    volumeMounted: mounted
                    volumeBusy: busy
                    volumeOperation: operation

                    dockIndex: root.removableVolumeDockStartIndex + index
                    x: root.isVertical ? root.crossMargin
                        : root.baseCenterForIndex(dockIndex) - scaledSize / 2
                    y: root.isVertical
                        ? root.baseCenterForIndex(dockIndex) - scaledSize / 2
                        : root.crossMargin
                }
            }

            UtilityDelegate {
                id: trashBaseItem

                visible: root.showTrash
                dockIndex: root.trashDockIndex
                utilityType: "trash"
                x: root.isVertical ? root.crossMargin
                    : root.baseCenterForIndex(dockIndex) - scaledSize / 2
                y: root.isVertical
                    ? root.baseCenterForIndex(dockIndex) - scaledSize / 2
                    : root.crossMargin
            }

            PowerDelegate {
                id: powerBaseItem

                visible: root.showPowerButton
                dockIndex: root.powerButtonDockIndex
                x: root.isVertical ? root.crossMargin
                    : root.baseCenterForIndex(dockIndex) - scaledSize / 2
                y: root.isVertical
                    ? root.baseCenterForIndex(dockIndex) - scaledSize / 2
                    : root.crossMargin
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
            && !root.fullscreenWindowPresent && !root.dockWindowVisible

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
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.keyboardInteractivity:
            LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.activateOnShow: false
        LayerShell.Window.wantsToBeOnActiveScreen: true

        onVisibleChanged: {
            if (!visible) {
                root.edgeHovered = false;
                root.scheduleDockHide();
            }
            // Fensterwechsel: die neu gemappte Fläche muss die Geometrie
            // übernehmen, sonst zeigt KWin weiter auf die zerstörte alte.
            root.republishTaskGeometry();
            geometryRepublishTimer.restart();
        }

        Item {
            anchors.fill: parent

            // Ist das Dock automatisch versteckt (Vollbild oder maximiertes
            // Fenster bei hideOnMaximized), sind Basis- und Overlay-Fenster
            // nicht gemappt. Ihre wl_surface existiert dann nicht mehr und KWin
            // verliert die veröffentlichte Minimier-Geometrie — die Animation
            // fliegt anschließend in eine Ersatzposition statt zum Icon.
            //
            // Dieses Kantenfenster ist genau in diesem Zustand gemappt und
            // exakt so lang wie das Dock. Wir veröffentlichen die Geometrie
            // deshalb hier weiter: an der Bildschirmkante, aber an der
            // richtigen Position des jeweiligen Icons.
            Repeater {
                id: edgeGeometryRepeater

                model: tasksModel

                delegate: Item {
                    id: edgeGeometryProxy

                    required property int index

                    readonly property real proxyCenter: root.baseCenterForIndex(
                        root.taskDockStartIndex
                            + root.visualIndexForModelIndex(index))

                    // Unsichtbar, aber nicht `visible: false` — die Geometrie
                    // eines Items muss im Szenengraph auflösbar bleiben.
                    opacity: 0
                    width: root.isVertical ? edgeWindow.width : root.baseIconSize
                    height: root.isVertical ? root.baseIconSize : edgeWindow.height
                    x: root.isVertical ? 0 : proxyCenter - width / 2
                    y: root.isVertical ? proxyCenter - height / 2 : 0

                    function publishEdgeGeometry() {
                        if (!edgeWindow.visible) {
                            return;
                        }
                        root.publishDelegateGeometry(index, edgeGeometryProxy,
                            edgeWindow);
                    }

                    onXChanged: Qt.callLater(publishEdgeGeometry)
                    onYChanged: Qt.callLater(publishEdgeGeometry)
                    onWidthChanged: Qt.callLater(publishEdgeGeometry)
                    onHeightChanged: Qt.callLater(publishEdgeGeometry)
                    Component.onCompleted: Qt.callLater(publishEdgeGeometry)
                }
            }

            FolderDropTarget {
                anchors.fill: parent
                z: 1
            }

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
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.keyboardInteractivity:
            LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.activateOnShow: false
        LayerShell.Window.wantsToBeOnActiveScreen: true

        onVisibleChanged: {
            if (!visible) {
                root.overlayHovered = false;
            }
            root.republishTaskGeometry();
            geometryRepublishTimer.restart();
        }

        Item {
            id: overlayContent

            anchors.fill: parent
            transform: Translate {
                x: root.dockSlideX(overlayWindow.width)
                y: root.dockSlideY(overlayWindow.height)
            }

            readonly property real mainLength: root.isVertical ? height : width
            readonly property var itemGeometry: calculateItemGeometry()
            readonly property real currentIconMainLength:
                itemGeometry.iconMainLength
            readonly property real currentMainLength: itemGeometry.mainLength

            function scaleAtDockIndex(index) {
                var item = null;
                if (index >= root.taskDockStartIndex
                        && index < root.taskDockStartIndex
                            + root.taskVisualCount) {
                    var taskVisualIndex =
                        index - root.taskDockStartIndex;
                    item = overlayRepeater.itemAt(
                        root.modelIndexForVisualIndex(taskVisualIndex));
                } else if (index >= root.folderDockIndex
                        && index < root.folderDockIndex
                            + root.folderItemCount) {
                    item = folderOverlayRepeater.itemAt(
                        index - root.folderDockIndex);
                } else if (index >= root.removableVolumeDockStartIndex
                        && index < root.removableVolumeDockStartIndex
                            + root.removableVolumeCount) {
                    item = removableVolumeOverlayRepeater.itemAt(
                        index - root.removableVolumeDockStartIndex);
                } else if (index === root.trashDockIndex) {
                    item = trashOverlayItem;
                } else if (index === root.powerButtonDockIndex) {
                    item = powerOverlayItem;
                }
                // Repeater.itemAt() is statically typed as Item, while every
                // Dock item has currentScale.
                // qmllint disable missing-property
                var scale = item ? Number(item["currentScale"]) : 1.0;
                // qmllint enable missing-property
                return Number.isFinite(scale) ? scale : 1.0;
            }

            function calculateItemGeometry() {
                var count = root.dockItemCount;
                if (count <= 0) {
                    return {
                        iconMainLength: 0,
                        mainLength: root.desktopSwitcherMainExtent,
                        centers: [],
                        extents: []
                    };
                }

                var iconMainLength = Math.max(0, count - 1) * root.itemSpacing
                    + root.sectionBreakAfterDockIndices.length
                        * root.utilitySectionGap;
                var extents = [];
                for (var index = 0; index < count; ++index) {
                    var extent = root.baseIconSize
                        * scaleAtDockIndex(index);
                    extents.push(extent);
                    iconMainLength += extent;
                }

                var currentMainLength = iconMainLength
                    + root.desktopSwitcherMainExtent
                    + root.desktopSwitcherSectionSpacing;
                var cursor = (mainLength - currentMainLength) / 2
                    + root.desktopSwitcherLeadingExtent;
                var centers = [];
                for (var visualIndex = 0; visualIndex < count;
                        ++visualIndex) {
                    centers.push(cursor + extents[visualIndex] / 2);
                    cursor += extents[visualIndex] + root.itemSpacing;
                    if (root.hasSectionBreakAfterDockIndex(visualIndex)) {
                        cursor += root.utilitySectionGap;
                    }
                }
                return {
                    iconMainLength: iconMainLength,
                    mainLength: currentMainLength,
                    centers: centers,
                    extents: extents
                };
            }

            function centerForVisualIndex(index) {
                return index >= 0 && index < itemGeometry.centers.length
                    ? itemGeometry.centers[index] : 0;
            }

            function centerForModelIndex(index) {
                return centerForVisualIndex(
                    root.taskDockStartIndex
                        + root.visualIndexForModelIndex(index));
            }

            function separatorPositionAfter(index) {
                if (index < 0 || index >= itemGeometry.centers.length) {
                    return 0;
                }
                return itemGeometry.centers[index]
                    + itemGeometry.extents[index] / 2
                    + (root.itemSpacing + root.utilitySectionGap) / 2;
            }

            function desktopSwitcherStart() {
                var start = (mainLength - currentMainLength) / 2;
                if (root.desktopSwitcherOnLeft
                        || root.dockItemCount === 0) {
                    return start;
                }
                return start + currentIconMainLength
                    + root.desktopSwitcherSectionSpacing;
            }

            function desktopSeparatorPosition() {
                if (!root.desktopSwitcherVisible
                        || root.dockItemCount === 0) {
                    return 0;
                }
                var start = (mainLength - currentMainLength) / 2;
                return root.desktopSwitcherOnLeft
                    ? start + root.desktopSwitcherMainExtent
                        + root.desktopSwitcherSectionSpacing / 2
                    : start + currentIconMainLength
                        + root.desktopSwitcherSectionSpacing / 2;
            }

            function desktopSwitcherCrossStart(crossExtent) {
                if (!root.isVertical) {
                    if (root.dockLocation === PlasmaCore.Types.TopEdge) {
                        return 0;
                    }
                    if (root.dockLocation === PlasmaCore.Types.BottomEdge) {
                        return root.maximumIconSize - crossExtent;
                    }
                } else {
                    if (root.dockLocation === PlasmaCore.Types.LeftEdge) {
                        return 0;
                    }
                    if (root.dockLocation === PlasmaCore.Types.RightEdge) {
                        return root.maximumIconSize - crossExtent;
                    }
                }
                return (root.maximumIconSize - crossExtent) / 2;
            }

            function visualIndexAtMainPosition(pos) {
                var count = root.taskVisualCount;
                if (count <= 0) {
                    return -1;
                }
                var bestIndex = 0;
                var minDiff = Math.abs(pos - centerForVisualIndex(
                    root.taskDockStartIndex));
                for (var i = 1; i < count; ++i) {
                    var diff = Math.abs(pos - centerForVisualIndex(
                        root.taskDockStartIndex + i));
                    if (diff < minDiff) {
                        minDiff = diff;
                        bestIndex = i;
                    }
                }
                return bestIndex;
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

            FolderDropTarget {
                x: overlayBackgroundSurface.x
                y: overlayBackgroundSurface.y
                width: overlayBackgroundSurface.width
                height: overlayBackgroundSurface.height
                z: 1
                excludedItems: [trashOverlayItem, powerOverlayItem]
            }

            Rectangle {
                x: overlayBackgroundSurface.x
                y: overlayBackgroundSurface.y
                width: overlayBackgroundSurface.width
                height: overlayBackgroundSurface.height
                z: 9998
                visible: root.folderDropActive
                color: "transparent"
                radius: root.cornerRadius
                border.width: 2
                border.color: Kirigami.Theme.highlightColor
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

            TrackedMenu {
                id: dockMenu

                QQC2.MenuItem {
                    text: i18n("Configure Dock…")
                    icon.name: "configure"
                    onTriggered: Plasmoid.internalAction("configure").trigger()
                }
            }

            Item {
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
                    model: root.sectionBreakAfterDockIndices

                    delegate: Rectangle {
                        required property int modelData

                        color: Kirigami.Theme.textColor
                        opacity: 0.24
                        radius: 1
                        width: root.isVertical
                            ? root.baseIconSize * 0.62 : 1
                        height: root.isVertical
                            ? 1 : root.baseIconSize * 0.62
                        x: root.isVertical
                            ? (root.maximumIconSize - width) / 2
                            : overlayContent.separatorPositionAfter(modelData)
                                - width / 2
                        y: root.isVertical
                            ? overlayContent.separatorPositionAfter(modelData)
                                - height / 2
                            : (root.maximumIconSize - height) / 2
                    }
                }

                Rectangle {
                    visible: root.desktopSwitcherVisible
                        && root.dockItemCount > 0
                    color: Kirigami.Theme.textColor
                    opacity: 0.24
                    radius: 1
                    width: root.isVertical
                        ? root.baseIconSize * 0.62 : 1
                    height: root.isVertical
                        ? 1 : root.baseIconSize * 0.62
                    x: root.isVertical
                        ? (root.maximumIconSize - width) / 2
                        : overlayContent.desktopSeparatorPosition()
                            - width / 2
                    y: root.isVertical
                        ? overlayContent.desktopSeparatorPosition()
                            - height / 2
                        : (root.maximumIconSize - height) / 2
                }

                DesktopSwitcher {
                    visible: root.desktopSwitcherVisible
                    x: root.isVertical
                        ? overlayContent.desktopSwitcherCrossStart(crossExtent)
                        : overlayContent.desktopSwitcherStart()
                    y: root.isVertical
                        ? overlayContent.desktopSwitcherStart()
                        : overlayContent.desktopSwitcherCrossStart(crossExtent)
                }

                Repeater {
                    id: overlayRepeater

                    model: tasksModel

                    delegate: TaskDelegate {
                        inOverlay: true
                        displayScale: root.scaleForIndex(
                            root.taskDockStartIndex
                                + root.visualIndexForModelIndex(index),
                            root.lastPointerMain, root.overlayOpen,
                            overlayContent.mainLength, root.maxScale,
                            root.baseIconSize)
                        displayCrossExtent: root.maximumIconSize
                        x: root.isVertical ? 0
                            : overlayContent.centerForModelIndex(index)
                                - scaledSize / 2
                        y: root.isVertical
                            ? overlayContent.centerForModelIndex(index)
                                - scaledSize / 2 : 0
                    }
                }

                Repeater {
                    id: folderOverlayRepeater

                    model: root.folderItemCount

                    delegate: UtilityDelegate {
                        required property int index

                        inOverlay: true
                        folderIndex: index
                        folderUrl: root.folderUrlAt(index)
                        dockIndex: root.folderDockIndex + index
                        utilityType: "folder"
                        displayScale: root.scaleForIndex(dockIndex,
                            root.lastPointerMain, root.overlayOpen,
                            overlayContent.mainLength, root.maxScale,
                            root.baseIconSize)
                        displayCrossExtent: root.maximumIconSize
                        x: root.isVertical ? 0
                            : overlayContent.centerForVisualIndex(dockIndex)
                                - scaledSize / 2
                        y: root.isVertical
                            ? overlayContent.centerForVisualIndex(dockIndex)
                                - scaledSize / 2 : 0
                    }
                }

                Repeater {
                    id: removableVolumeOverlayRepeater

                    model: root.showRemovableVolumes ? removableVolumesModel : 0

                    delegate: RemovableVolumeDelegate {
                        required property int index
                        required property string udi
                        required property string displayName
                        required property string iconName
                        required property string kind
                        required property string errorText
                        required property bool canOpen
                        required property bool canRemove
                        required property bool mounted
                        required property bool busy
                        required property string operation

                        volumeUdi: udi
                        volumeDisplayName: displayName
                        volumeIconName: iconName
                        volumeKind: kind
                        volumeCanOpen: canOpen
                        volumeCanRemove: canRemove
                        volumeErrorText: errorText
                        volumeMounted: mounted
                        volumeBusy: busy
                        volumeOperation: operation

                        dockIndex: root.removableVolumeDockStartIndex + index
                        displayScale: root.scaleForIndex(dockIndex,
                            root.lastPointerMain, root.overlayOpen,
                            overlayContent.mainLength, root.maxScale,
                            root.baseIconSize)
                        displayCrossExtent: root.maximumIconSize
                        x: root.isVertical ? 0
                            : overlayContent.centerForVisualIndex(dockIndex)
                                - scaledSize / 2
                        y: root.isVertical
                            ? overlayContent.centerForVisualIndex(dockIndex)
                                - scaledSize / 2 : 0
                    }
                }

                UtilityDelegate {
                    id: trashOverlayItem

                    visible: root.showTrash
                    inOverlay: true
                    dockIndex: root.trashDockIndex
                    utilityType: "trash"
                    displayScale: root.scaleForIndex(dockIndex,
                        root.lastPointerMain, root.overlayOpen,
                        overlayContent.mainLength, root.maxScale,
                        root.baseIconSize)
                    displayCrossExtent: root.maximumIconSize
                    x: root.isVertical ? 0
                        : overlayContent.centerForVisualIndex(dockIndex)
                            - scaledSize / 2
                    y: root.isVertical
                        ? overlayContent.centerForVisualIndex(dockIndex)
                            - scaledSize / 2 : 0
                }

                PowerDelegate {
                    id: powerOverlayItem

                    visible: root.showPowerButton
                    dockIndex: root.powerButtonDockIndex
                    displayScale: root.scaleForIndex(dockIndex,
                        root.lastPointerMain, root.overlayOpen,
                        overlayContent.mainLength, root.maxScale,
                        root.baseIconSize)
                    displayCrossExtent: root.maximumIconSize
                    x: root.isVertical ? 0
                        : overlayContent.centerForVisualIndex(dockIndex)
                            - scaledSize / 2
                    y: root.isVertical
                        ? overlayContent.centerForVisualIndex(dockIndex)
                            - scaledSize / 2 : 0
                }
            }
        }
    }
}
