pragma ComponentBehavior: Bound

import QtQuick

// Bridges QML to the native FolderWatcher (API version 5+) so missing folders
// stay hidden in the Dock and appear/disappear live on filesystem changes.
//
// When running against an older native plugin in memory before plasmashell is
// restarted, falls back to an optional synchronous fallbackExistsFn callback.
QtObject {
    id: root

    property var watchedUrls: []
    property int pluginApiVersion: 0
    property int requiredApiVersion: 5
    property var fallbackExistsFn: null

    property string watcherSource:
        "import QtQuick\nimport \"effects\" as Effects\nEffects.FolderWatcher {}"

    property var watcher: null
    property int revision: 0
    property var currentExistingUrls: []
    readonly property var existingUrls: root.currentExistingUrls

    onWatchedUrlsChanged: root.syncWatchedUrls()
    onFallbackExistsFnChanged: root.refreshExistingUrls()
    onPluginApiVersionChanged: root.ensureWatcher()
    Component.onCompleted: {
        root.ensureWatcher();
        root.refreshExistingUrls();
    }

    Component.onDestruction: {
        if (root.watcher) {
            root.watcher.destroy();
            root.watcher = null;
        }
    }

    function sameUrlList(first, second) {
        let a = first || [];
        let b = second || [];
        if (a.length !== b.length) {
            return false;
        }
        for (let i = 0; i < a.length; ++i) {
            if (String(a[i]) !== String(b[i])) {
                return false;
            }
        }
        return true;
    }

    function refreshExistingUrls() {
        let urls = root.watchedUrls || [];
        let next = [];
        if (urls.length > 0) {
            if (root.watcher) {
                // qmllint disable missing-property
                let watcherUrls = root.watcher["existingUrls"] || [];
                // qmllint enable missing-property
                for (let i = 0; i < watcherUrls.length; ++i) {
                    next.push(String(watcherUrls[i]));
                }
            } else if (typeof root.fallbackExistsFn === "function") {
                for (let i = 0; i < urls.length; ++i) {
                    if (root.fallbackExistsFn(urls[i])) {
                        next.push(String(urls[i]));
                    }
                }
            } else {
                for (let i = 0; i < urls.length; ++i) {
                    next.push(String(urls[i]));
                }
            }
        }

        if (!root.sameUrlList(root.currentExistingUrls, next)) {
            root.currentExistingUrls = next;
        }
        ++root.revision;
    }

    function ensureWatcher() {
        if (root.watcher || root.pluginApiVersion < root.requiredApiVersion) {
            root.syncWatchedUrls();
            return;
        }
        try {
            let created = Qt.createQmlObject(root.watcherSource, root,
                Qt.resolvedUrl("FolderPresenceController.qml"));
            if (!created) {
                return;
            }
            root.watcher = created;
            root.syncWatchedUrls();
            // qmllint disable missing-property
            let changedSignal = created["existingUrlsChanged"];
            if (changedSignal) {
                changedSignal.connect(function () {
                    root.refreshExistingUrls();
                });
            }
            // qmllint enable missing-property
        } catch (error) {
            console.warn("macOS Dock: failed to create FolderWatcher:", error);
            root.watcher = null;
            root.refreshExistingUrls();
        }
    }

    function syncWatchedUrls() {
        if (root.watcher) {
            let normalized = [];
            let source = root.watchedUrls || [];
            for (let i = 0; i < source.length; ++i) {
                normalized.push(String(source[i] || ""));
            }
            // qmllint disable missing-property
            root.watcher["watchedUrls"] = normalized;
            // qmllint enable missing-property
        }
        root.refreshExistingUrls();
    }

    function directoryExists(folderUrl) {
        void root.revision;
        let url = String(folderUrl || "").trim();
        if (url.length === 0) {
            return false;
        }
        if (root.watcher) {
            // qmllint disable missing-property
            return Boolean(root.watcher.directoryExists(url));
            // qmllint enable missing-property
        }
        if (typeof root.fallbackExistsFn === "function") {
            return Boolean(root.fallbackExistsFn(url));
        }
        return true;
    }
}
