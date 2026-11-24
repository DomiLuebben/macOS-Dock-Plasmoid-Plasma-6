pragma ComponentBehavior: Bound

import QtQuick

// Bridges main.qml to the native LauncherMonitor (API version 4+) at runtime.
//
// Creating the native monitor dynamically keeps main.qml loadable when an
// in-place package update leaves an older native plugin in memory until
// plasmashell is restarted.
QtObject {
    id: root

    property bool enabled: true
    property int pluginApiVersion: 0
    property int requiredApiVersion: 4

    // Overridable so QML unit tests can inject a stub monitor without KSycoca.
    property string monitorSource:
        "import QtQuick\nimport \"effects\" as Effects\nEffects.LauncherMonitor {}"

    property var monitor: null
    readonly property bool available: monitor !== null

    signal checkRequested()

    onEnabledChanged: {
        if (root.monitor) {
            // qmllint disable missing-property
            root.monitor["enabled"] = root.enabled;
            // qmllint enable missing-property
        }
        if (root.enabled && root.monitor) {
            root.checkRequested();
        }
    }

    onPluginApiVersionChanged: root.ensureMonitor()
    Component.onCompleted: root.ensureMonitor()

    Component.onDestruction: {
        if (root.monitor) {
            root.monitor.destroy();
            root.monitor = null;
        }
    }

    function ensureMonitor() {
        if (root.monitor || root.pluginApiVersion < root.requiredApiVersion) {
            return;
        }
        try {
            let created = Qt.createQmlObject(root.monitorSource, root,
                Qt.resolvedUrl("LauncherCleanupController.qml"));
            if (!created) {
                return;
            }
            // qmllint disable missing-property
            created["enabled"] = root.enabled;
            let changedSignal = created["applicationsChanged"];
            if (changedSignal) {
                changedSignal.connect(root.checkRequested);
            }
            // qmllint enable missing-property
            root.monitor = created;
            if (root.enabled) {
                root.checkRequested();
            }
        } catch (error) {
            console.warn("macOS Dock: failed to create LauncherMonitor:", error);
            root.monitor = null;
        }
    }

    function findMissingLaunchers(launcherUrls) {
        if (!root.enabled || !root.monitor || !launcherUrls
                || launcherUrls.length === 0) {
            return [];
        }
        // qmllint disable missing-property
        return root.monitor.missingLaunchers(launcherUrls) || [];
        // qmllint enable missing-property
    }
}
