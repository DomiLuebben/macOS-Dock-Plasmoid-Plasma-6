import QtQuick
import org.kde.notificationmanager as NotificationManager
import "effects" as DockEffects

Item {
    id: root

    property bool enabled: true

    // Internal maps storing state
    // Key: normalized desktop ID or folder path
    property var appProgressState: ({})
    property var folderProgressState: ({})

    signal progressUpdated()

    DockEffects.LauncherProgressMonitor {
        id: unityMonitor
        onProgressUpdated: (desktopId, progress, visible) => {
            root.handleUnityUpdate(desktopId, progress, visible);
        }
    }

    NotificationManager.JobsModel {
        id: jobsModel
        onRowsInserted: (parent, first, last) => root.scheduleUpdate()
        onRowsRemoved: (parent, first, last) => root.scheduleUpdate()
        onDataChanged: (topLeft, bottomRight, roles) => root.scheduleUpdate()
        onModelReset: () => root.scheduleUpdate()
    }

    function normalizeDesktopId(rawId) {
        if (!rawId) return "";
        var id = String(rawId).trim();
        if (id.startsWith("application://")) {
            id = id.substring(14);
        } else if (id.startsWith("applications:")) {
            id = id.substring(13);
        }
        var qIdx = id.indexOf("?");
        if (qIdx !== -1) {
            id = id.substring(0, qIdx);
        }
        if (id.toLowerCase().endsWith(".desktop")) {
            id = id.substring(0, id.length - 8);
        }
        return id.toLowerCase();
    }

    function normalizeUrl(rawUrl) {
        if (!rawUrl) return "";
        var url = String(rawUrl).trim();
        if (url.startsWith("file://")) {
            url = url.substring(7);
        }
        return url;
    }

    function scheduleUpdate() {
        Qt.callLater(recalculateProgress);
    }

    property var unityState: ({})

    function handleUnityUpdate(desktopId, progress, visible) {
        var norm = normalizeDesktopId(desktopId);
        if (!norm) return;
        var newUnity = Object.assign({}, unityState);
        newUnity[norm] = {
            progress: Math.max(0.0, Math.min(1.0, progress)),
            visible: Boolean(visible)
        };
        unityState = newUnity;
        scheduleUpdate();
    }

    function recalculateProgress() {
        if (!root.enabled) {
            appProgressState = {};
            folderProgressState = {};
            progressUpdated();
            return;
        }

        var appJobs = {};
        var folderJobs = {};

        var count = jobsModel.rowCount();
        for (var i = 0; i < count; i++) {
            var idx = jobsModel.index(i, 0);
            var dEntry = normalizeDesktopId(jobsModel.data(idx, NotificationManager.JobsModel.DesktopEntryRole || 267) || jobsModel.data(idx, 267) || "");
            var state = jobsModel.data(idx, NotificationManager.JobsModel.StateRole || 259) || jobsModel.data(idx, 259);
            var pct = jobsModel.data(idx, NotificationManager.JobsModel.PercentageRole || 263) || jobsModel.data(idx, 263);
            var procBytes = Number(jobsModel.data(idx, NotificationManager.JobsModel.ProcessedBytesRole || 265) || jobsModel.data(idx, 265) || 0);
            var totBytes = Number(jobsModel.data(idx, NotificationManager.JobsModel.TotalBytesRole || 266) || jobsModel.data(idx, 266) || 0);
            var rawDest = jobsModel.data(idx, NotificationManager.JobsModel.DestUrlRole || 268) || jobsModel.data(idx, 268) ||
                          jobsModel.data(idx, NotificationManager.JobsModel.EffectiveDestUrlRole || 269) || jobsModel.data(idx, 269) || "";
            var destPath = normalizeUrl(rawDest);

            // Job active check
            var isRunning = (state === undefined || state === 0 || state === 1 || state === "running");

            if (isRunning) {
                var jobData = {
                    percentage: Number(pct !== undefined ? pct : 0),
                    processedBytes: procBytes,
                    totalBytes: totBytes
                };

                if (dEntry) {
                    if (!appJobs[dEntry]) appJobs[dEntry] = [];
                    appJobs[dEntry].push(jobData);
                }

                if (destPath) {
                    if (!folderJobs[destPath]) folderJobs[destPath] = [];
                    folderJobs[destPath].push(jobData);
                }
            }
        }

        // Aggregate for apps
        var newAppMap = {};
        for (var appKey in appJobs) {
            newAppMap[appKey] = aggregateJobGroup(appJobs[appKey]);
        }

        // Add Unity fallbacks if no KJob targets the app
        for (var uKey in unityState) {
            if (!newAppMap[uKey] && unityState[uKey] && unityState[uKey].visible) {
                newAppMap[uKey] = {
                    visible: true,
                    progress: unityState[uKey].progress,
                    indeterminate: false
                };
            }
        }

        appProgressState = newAppMap;
        folderProgressState = folderJobs;
        progressUpdated();
    }

    function aggregateJobGroup(jobs) {
        if (!jobs || jobs.length === 0) {
            return { visible: false, progress: 0.0, indeterminate: false };
        }

        var sumProcessed = 0;
        var sumTotal = 0;
        var hasByteTotals = true;
        var sumPct = 0;

        for (var j = 0; j < jobs.length; j++) {
            var job = jobs[j];
            if (job.totalBytes && job.totalBytes > 0) {
                sumProcessed += job.processedBytes;
                sumTotal += job.totalBytes;
            } else {
                hasByteTotals = false;
            }
            sumPct += job.percentage;
        }

        var finalProgress = 0.0;
        if (hasByteTotals && sumTotal > 0) {
            finalProgress = sumProcessed / sumTotal;
        } else {
            var avgPct = sumPct / jobs.length;
            finalProgress = avgPct > 1.0 ? avgPct / 100.0 : avgPct;
        }

        finalProgress = Math.max(0.0, Math.min(1.0, finalProgress));

        return {
            visible: true,
            progress: finalProgress,
            indeterminate: (finalProgress === 0.0 && !hasByteTotals)
        };
    }

    function getAppProgress(desktopId, appName) {
        var normId = normalizeDesktopId(desktopId);
        var normName = normalizeDesktopId(appName);

        if (normId && appProgressState[normId]) {
            return appProgressState[normId];
        }
        if (normName && appProgressState[normName]) {
            return appProgressState[normName];
        }
        return { visible: false, progress: 0.0, indeterminate: false };
    }

    function getFolderProgress(folderPath) {
        var normFolder = normalizeUrl(folderPath);
        if (!normFolder) {
            return { visible: false, progress: 0.0, indeterminate: false };
        }

        if (!normFolder.endsWith("/")) {
            normFolder += "/";
        }

        var matchingJobs = [];
        for (var destPath in folderProgressState) {
            if (destPath.startsWith(normFolder) || (destPath + "/").startsWith(normFolder)) {
                var jobs = folderProgressState[destPath];
                for (var k = 0; k < jobs.length; k++) {
                    matchingJobs.push(jobs[k]);
                }
            }
        }

        return aggregateJobGroup(matchingJobs);
    }
}
