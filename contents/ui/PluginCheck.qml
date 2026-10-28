import QtQuick

// Asks the native plugin that is loaded in this process which API it offers and
// compares it with what this QML needs.
//
// The probe is created at run time instead of being written into the QML on
// purpose: a plugin from before PluginInfo existed does not know the type, and
// a static reference would stop the whole dock from loading. A failed probe
// simply reads as API version 0.
QtObject {
    id: root

    // The API level this QML was written for (see native/plugininfo.h).
    readonly property int requiredApiVersion: 3

    // Overridable so tests can stand in for a plugin without PluginInfo.
    property string probeSource: 'import QtQuick
import "effects" as Effects
Effects.PluginInfo {}'

    property int apiVersion: 0
    readonly property bool current: apiVersion >= requiredApiVersion
    readonly property string message: current ? "" :
        "macOS Dock: the native plugin in memory has API version " + apiVersion
        + " but this QML needs " + requiredApiVersion
        + ". The widget was updated while Plasma was running. Restart plasmashell"
        + " (systemctl --user restart plasma-plasmashell.service)."

    Component.onCompleted: {
        try {
            var probe = Qt.createQmlObject(root.probeSource, root,
                Qt.resolvedUrl("PluginCheck.qml"));
            root.apiVersion = Number(probe.apiVersion) || 0;
            probe.destroy();
        } catch (error) {
            root.apiVersion = 0;
        }
        if (!root.current) {
            console.warn(root.message);
        }
    }
}
