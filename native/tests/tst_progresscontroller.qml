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
}
