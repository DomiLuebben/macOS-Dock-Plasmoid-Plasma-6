import QtQuick
import QtTest
import "../../contents/ui"

TestCase {
    name: "ProgressController"

    Component {
        id: controllerComponent

        ProgressController {
            monitoringEnabled: false
        }
    }

    Component {
        id: monitoringController

        ProgressController {
            monitoringEnabled: true
            badgesEnabled: true
        }
    }

    // Instantiates the native monitor. Must work whether the plugin in memory is
    // current or older than this QML (no countUpdated signal): a static handler
    // for the new signal used to stop the whole component from loading.
    function test_monitorLoadsWithEitherPluginGeneration() {
        var controller = createTemporaryObject(monitoringController, this);
        verify(controller);
        controller.handleUnityUpdate("application://org.example.dl.desktop", 0.4, true);
        compare(controller.unityState["org.example.dl"].progress, 0.4);
        wait(100);
        verify(controller);
    }

    function test_wineExecutableUsesDesktopLauncherProgress() {
        var controller = createTemporaryObject(controllerComponent, this);
        verify(controller);

        controller.appProgressState = {
            affinity: {
                visible: true,
                progress: 0.5,
                indeterminate: false,
                completing: false
            }
        };

        var progress = controller.getAppProgress(
            "affinity.exe", "application://affinity.exe");
        verify(progress.visible);
        compare(progress.progress, 0.5);
    }

    function test_standardDesktopIdentityStaysCompatible() {
        var controller = createTemporaryObject(controllerComponent, this);
        verify(controller);

        compare(controller.normalizeDesktopId(
            "applications:Org.Kde.Dolphin.desktop?icon=x"),
            "org.kde.dolphin");
        compare(controller.normalizeDesktopId(
            "file:///usr/share/applications/org.kde.dolphin.desktop"),
            "org.kde.dolphin");
    }

    function test_unityCountSurvivesUntilHidden() {
        var controller = createTemporaryObject(controllerComponent, this);
        verify(controller);

        controller.handleUnityCount("application://org.example.chat.desktop", 4, true);
        compare(controller.getAppBadgeCount("org.example.chat", ""), 4);

        controller.handleUnityCount("org.example.chat", 0, false);
        compare(controller.getAppBadgeCount("org.example.chat", ""), 0);
    }

    function test_badgeLookupFallsBackToTheLauncher() {
        var controller = createTemporaryObject(controllerComponent, this);
        verify(controller);

        controller.notificationCounts = { affinity: 2 };
        compare(controller.getAppBadgeCount("affinity.exe", "application://affinity.exe"), 2);
        compare(controller.getAppBadgeCount("", "applications:affinity.desktop"), 2);
        compare(controller.getAppBadgeCount("other", ""), 0);
    }

    function test_activatingAnAppRecordsWhenItWasSeen() {
        var controller = createTemporaryObject(controllerComponent, this);
        verify(controller);

        var before = Date.now();
        controller.setAppActive("org.example.chat", "", true);
        verify(controller.activeApps["org.example.chat"]);
        verify(controller.seenAt["org.example.chat"] >= before);

        controller.setAppActive("org.example.chat", "", false);
        verify(!controller.activeApps["org.example.chat"]);
        verify(controller.seenAt["org.example.chat"] >= before);
    }

    function test_badgesAreOffWhenDisabled() {
        var controller = createTemporaryObject(controllerComponent, this);
        verify(controller);

        controller.badgesEnabled = false;
        controller.notificationCounts = { telegram: 3 };
        controller.recalculateBadges();
        compare(controller.getAppBadgeCount("telegram", ""), 0);
    }
}
