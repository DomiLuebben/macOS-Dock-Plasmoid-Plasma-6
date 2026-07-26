pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models
import org.kde.notificationmanager as NotificationManager
import "AppGroupStore.js" as AppGroupStore
import "effects" as DockEffects

Item {
    id: root

    property bool monitoringEnabled: true

    // Assigning fresh objects is intentional: consumers use these properties
    // as their change notification instead of polling the models.
    property var appProgressState: ({})
    property var folderProgressState: ({})
    property var unityState: ({})
    property var appCompletionState: ({})
    property var folderCompletionState: ({})

    property bool updatePending: false

    width: 0
    height: 0

    Timer {
        id: completionTimer
        interval: 520
        repeat: false
        onTriggered: {
            root.appCompletionState = {};
            root.folderCompletionState = {};
            root.scheduleUpdate();
        }
    }

    Timer {
        id: updateTimer
        interval: 33
        repeat: false
        onTriggered: root.recalculateProgress()
    }

    Loader {
        active: root.monitoringEnabled
        sourceComponent: Component {
            DockEffects.LauncherProgressMonitor {
                onProgressUpdated: (desktopId, progress, visible) => {
                    root.handleUnityUpdate(desktopId, progress, visible);
                }
            }
        }
    }

    NotificationManager.Notifications {
        id: jobsModel

        showNotifications: false
        showJobs: root.monitoringEnabled
        showExpired: false
        showDismissed: false
        groupMode: NotificationManager.Notifications.GroupDisabled
    }

    component JobItem: QtObject {
        id: jobItem

        required property string desktopEntry
        required property int jobState
        required property int percentage
        required property var jobDetails
        property bool completionRecorded: false

        property Connections detailsConnections: Connections {
            target: jobItem.jobDetails
            function onDestUrlChanged() { root.scheduleUpdate(); }
            function onEffectiveDestUrlChanged() { root.scheduleUpdate(); }
            function onProcessedBytesChanged() { root.scheduleUpdate(); }
            function onTotalBytesChanged() { root.scheduleUpdate(); }
        }

        onDesktopEntryChanged: root.scheduleUpdate()
        onJobStateChanged: {
            root.maybeRecordCompletion(jobItem);
            root.scheduleUpdate();
        }
        onPercentageChanged: root.scheduleUpdate()
        onJobDetailsChanged: root.scheduleUpdate()
    }

    Instantiator {
        id: jobItems
        model: jobsModel
        delegate: JobItem {}

        onObjectAdded: root.scheduleUpdate()
        onObjectRemoved: (index, object) => {
            root.maybeRecordCompletion(object as JobItem);
            root.scheduleUpdate();
        }
    }

    function normalizeDesktopId(rawId) {
        // Launcher, group and progress matching must share one identity rule.
        // This also maps Wine/Proton executable IDs to their desktop launcher.
        return AppGroupStore.normalizeAppId(rawId);
    }

    function normalizeUrl(rawUrl) {
        if (!rawUrl) {
            return "";
        }

        var value = String(rawUrl).trim();
        var fragmentIndex = value.indexOf("#");
        if (fragmentIndex !== -1) {
            value = value.substring(0, fragmentIndex);
        }
        var queryIndex = value.indexOf("?");
        if (queryIndex !== -1) {
            value = value.substring(0, queryIndex);
        }

        try {
            value = decodeURI(value);
        } catch (error) {
            // Compare the encoded forms if the URL is malformed.
        }

        value = value.replace(/^file:/i, "file:");
        while (value.length > 1 && value.endsWith("/")
                && value !== "file:///") {
            value = value.substring(0, value.length - 1);
        }
        return value;
    }

    function scheduleUpdate() {
        if (root.updatePending) {
            return;
        }
        root.updatePending = true;
        updateTimer.start();
    }

    function handleUnityUpdate(desktopId, progress, visible) {
        var normalizedId = normalizeDesktopId(desktopId);
        if (!normalizedId) {
            return;
        }

        var updatedState = Object.assign({}, root.unityState);
        if (visible) {
            updatedState[normalizedId] = {
                progress: Math.max(0.0, Math.min(1.0, Number(progress))),
                visible: true
            };
        } else {
            var previous = updatedState[normalizedId];
            if (previous && previous.progress >= 0.999) {
                root.recordCompletion(normalizedId, "");
            }
            delete updatedState[normalizedId];
        }
        root.unityState = updatedState;
        root.scheduleUpdate();
    }

    function maybeRecordCompletion(item) {
        if (!item || item.completionRecorded) {
            return;
        }

        var details = item.jobDetails;
        var state = item.jobState;
        if (state !== NotificationManager.Notifications.JobStateStopped) {
            return;
        }

        var percentage = Number(item.percentage);
        var processedBytes = Number(details ? details.processedBytes : 0);
        var totalBytes = Number(details ? details.totalBytes : 0);
        var complete = percentage >= 100
            || (totalBytes > 0 && processedBytes >= totalBytes);
        if (!complete) {
            return;
        }

        item.completionRecorded = true;
        var desktopEntry = normalizeDesktopId(
            item.desktopEntry || (details ? details.desktopEntry : ""));
        var destination = normalizeUrl(details
            ? (details.effectiveDestUrl || details.destUrl) : "");
        root.recordCompletion(desktopEntry, destination);
    }

    function recordCompletion(desktopEntry, destination) {
        var changed = false;
        if (desktopEntry && !root.appCompletionState[desktopEntry]) {
            var appState = Object.assign({}, root.appCompletionState);
            appState[desktopEntry] = true;
            root.appCompletionState = appState;
            changed = true;
        }
        if (destination && !root.folderCompletionState[destination]) {
            var folderState = Object.assign({}, root.folderCompletionState);
            folderState[destination] = true;
            root.folderCompletionState = folderState;
            changed = true;
        }
        if (changed) {
            completionTimer.restart();
            root.scheduleUpdate();
        }
    }

    function recalculateProgress() {
        if (!root.monitoringEnabled) {
            root.appProgressState = {};
            root.folderProgressState = {};
            root.unityState = {};
            root.appCompletionState = {};
            root.folderCompletionState = {};
            completionTimer.stop();
            root.updatePending = false;
            return;
        }

        var appJobs = {};
        var folderJobs = {};

        for (var index = 0; index < jobItems.count; ++index) {
            var item = jobItems.objectAt(index) as JobItem;
            if (!item
                    || item.jobState === NotificationManager.Notifications.JobStateStopped) {
                root.maybeRecordCompletion(item);
                continue;
            }

            var details = item.jobDetails;
            var desktopEntry = normalizeDesktopId(
                item.desktopEntry || (details ? details.desktopEntry : ""));
            var rawPercentage = Number(
                details ? details.percentage : item.percentage);
            var processedBytes = Number(details ? details.processedBytes : 0);
            var totalBytes = Number(details ? details.totalBytes : 0);
            var destination = normalizeUrl(details
                ? (details.destUrl || details.effectiveDestUrl) : "");
            var job = {
                percentage: isFinite(rawPercentage) ? rawPercentage : -1,
                processedBytes: isFinite(processedBytes) ? processedBytes : 0,
                totalBytes: isFinite(totalBytes) ? totalBytes : 0
            };

            if (desktopEntry) {
                if (!appJobs[desktopEntry]) {
                    appJobs[desktopEntry] = [];
                }
                appJobs[desktopEntry].push(job);
            }

            if (destination) {
                if (!folderJobs[destination]) {
                    folderJobs[destination] = [];
                }
                folderJobs[destination].push(job);
            }
        }

        var appState = {};
        for (var appKey in appJobs) {
            appState[appKey] = root.aggregateJobGroup(appJobs[appKey]);
        }

        // KJob is richer and therefore wins whenever both transports report
        // the same operation.
        for (var unityKey in root.unityState) {
            if (!appState[unityKey]) {
                appState[unityKey] = {
                    visible: true,
                    progress: root.unityState[unityKey].progress,
                    indeterminate: false,
                    completing: false
                };
            }
        }

        for (var completedApp in root.appCompletionState) {
            if (!appState[completedApp]) {
                appState[completedApp] = {
                    visible: true,
                    progress: 1.0,
                    indeterminate: false,
                    completing: true
                };
            }
        }

        root.appProgressState = appState;
        root.folderProgressState = folderJobs;
        root.updatePending = false;
    }

    function aggregateJobGroup(jobs) {
        if (!jobs || jobs.length === 0) {
            return {
                visible: false,
                progress: 0.0,
                indeterminate: false,
                completing: false
            };
        }

        var allHaveByteTotals = true;
        var processedBytes = 0;
        var totalBytes = 0;
        var progressSum = 0;
        var knownProgressCount = 0;

        for (var index = 0; index < jobs.length; ++index) {
            var job = jobs[index];
            if (job.totalBytes > 0) {
                processedBytes += Math.max(0, job.processedBytes);
                totalBytes += job.totalBytes;
            } else {
                allHaveByteTotals = false;
            }

            if (job.totalBytes > 0) {
                progressSum += job.processedBytes / job.totalBytes;
                ++knownProgressCount;
            } else if (job.percentage > 0) {
                progressSum += job.percentage > 1
                    ? job.percentage / 100 : job.percentage;
                ++knownProgressCount;
            }
        }

        var progress = 0;
        if (allHaveByteTotals && totalBytes > 0) {
            progress = processedBytes / totalBytes;
        } else if (knownProgressCount > 0) {
            progress = progressSum / knownProgressCount;
        }

        return {
            visible: true,
            progress: Math.max(0.0, Math.min(1.0, progress)),
            indeterminate: knownProgressCount === 0,
            completing: false
        };
    }

    function getAppProgress(desktopId, launcherUrl) {
        var normalizedId = normalizeDesktopId(desktopId);
        if (normalizedId && root.appProgressState[normalizedId]) {
            return root.appProgressState[normalizedId];
        }
        var normalizedLauncher = normalizeDesktopId(launcherUrl);
        if (normalizedLauncher
                && root.appProgressState[normalizedLauncher]) {
            return root.appProgressState[normalizedLauncher];
        }
        return {
            visible: false,
            progress: 0.0,
            indeterminate: false,
            completing: false
        };
    }

    function getFolderProgress(folderUrl) {
        var normalizedFolder = normalizeUrl(folderUrl);
        if (!normalizedFolder) {
            return {
                visible: false,
                progress: 0.0,
                indeterminate: false,
                completing: false
            };
        }

        var matchingJobs = [];
        var completionMatches = false;
        var folderPrefix = normalizedFolder + "/";
        for (var destination in root.folderProgressState) {
            if (destination === normalizedFolder
                    || destination.startsWith(folderPrefix)) {
                var jobs = root.folderProgressState[destination];
                for (var index = 0; index < jobs.length; ++index) {
                    matchingJobs.push(jobs[index]);
                }
            }
        }
        for (var completedDestination in root.folderCompletionState) {
            if (completedDestination === normalizedFolder
                    || completedDestination.startsWith(folderPrefix)) {
                completionMatches = true;
                break;
            }
        }

        if (matchingJobs.length > 0) {
            return root.aggregateJobGroup(matchingJobs);
        }
        if (completionMatches) {
            return {
                visible: true,
                progress: 1.0,
                indeterminate: false,
                completing: true
            };
        }
        return {
            visible: false,
            progress: 0.0,
            indeterminate: false,
            completing: false
        };
    }

    onMonitoringEnabledChanged: root.scheduleUpdate()
    Component.onCompleted: root.scheduleUpdate()
}
