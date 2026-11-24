import QtQuick
import QtTest
import "../../contents/ui"

TestCase {
    name: "LauncherCleanupController"

    Component {
        id: olderPluginController
        LauncherCleanupController {
            pluginApiVersion: 3
        }
    }

    Component {
        id: activeController
        LauncherCleanupController {
            pluginApiVersion: 4
            monitorSource: 'import QtQuick
QtObject {
    property bool enabled: true
    property var uninstalled: ["applications:removed.desktop"]
    signal applicationsChanged()
    function missingLaunchers(urls) {
        var result = [];
        for (var i = 0; i < urls.length; ++i) {
            if (uninstalled.indexOf(urls[i]) !== -1) {
                result.push(urls[i]);
            }
        }
        return result;
    }
}'
        }
    }

    function test_staysDormantAgainstOlderPlugin() {
        var controller = createTemporaryObject(olderPluginController, this);
        verify(controller);
        verify(!controller.available);
        compare(controller.findMissingLaunchers([
            "applications:anything.desktop"
        ]).length, 0);
    }

    function test_reportsMissingLaunchersAndSignalsUpdates() {
        var controller = createTemporaryObject(activeController, this);
        verify(controller);
        verify(controller.available);

        var missing = controller.findMissingLaunchers([
            "preferred://browser",
            "applications:kept.desktop",
            "applications:removed.desktop"
        ]);
        compare(missing.length, 1);
        compare(missing[0], "applications:removed.desktop");

        var requests = 0;
        controller.checkRequested.connect(function () {
            ++requests;
        });
        controller.monitor.applicationsChanged();
        compare(requests, 1);

        controller.enabled = false;
        compare(controller.findMissingLaunchers([
            "applications:removed.desktop"
        ]).length, 0);
    }
}
