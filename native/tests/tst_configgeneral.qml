import QtQuick
import QtTest
import "../../contents/ui"

TestCase {
    name: "ConfigGeneral"

    Component {
        id: configComponent

        ConfigGeneral {}
    }

    function test_acceptsPersistedAppGroups() {
        failOnWarning(
            /ConfigGeneral does not have a property called cfg_appGroups/);

        var groups = ["{\"id\":\"assistants\"}"];
        var config = createTemporaryObject(configComponent, this, {
            cfg_appGroups: groups
        });
        verify(config);
        compare(config.cfg_appGroups, groups);
    }

    function test_acceptsAnimationConfiguration() {
        failOnWarning(
            /ConfigGeneral does not have a property called cfg_magnificationSpring/);

        var config = createTemporaryObject(configComponent, this, {
            cfg_magnificationSpring: 52.0,
            cfg_magnificationSpringDefault: 50.0,
            cfg_magnificationDamping: 0.95,
            cfg_magnificationDampingDefault: 1.0,
            cfg_clickBounceHeight: 5,
            cfg_clickBounceHeightDefault: 4,
            cfg_launchBounceHeight: 10,
            cfg_launchBounceHeightDefault: 8,
            cfg_dockRevealDuration: 220,
            cfg_dockRevealDurationDefault: 140,
            cfg_dockHideDuration: 250,
            cfg_dockHideDurationDefault: 160,
            cfg_appGroupPopupDuration: 280,
            cfg_appGroupPopupDurationDefault: 180,
            cfg_appGroupPopupOvershoot: 1.5,
            cfg_appGroupPopupOvershootDefault: 1.35,
            cfg_folderHoverScale: 1.08,
            cfg_folderHoverScaleDefault: 1.06
        });
        verify(config);
        compare(config.cfg_magnificationSpring, 52.0);
        compare(config.cfg_magnificationDamping, 0.95);
        compare(config.cfg_clickBounceHeight, 5);
        compare(config.cfg_launchBounceHeight, 10);
        compare(config.cfg_dockRevealDuration, 220);
        compare(config.cfg_dockHideDuration, 250);
        compare(config.cfg_appGroupPopupDuration, 280);
        compare(config.cfg_appGroupPopupOvershoot, 1.5);
        compare(config.cfg_folderHoverScale, 1.08);
    }

    function test_acceptsRemovableVolumeConfiguration() {
        failOnWarning(
            /ConfigGeneral does not have a property called cfg_openRemovableVolumesInNewTab/);

        var config = createTemporaryObject(configComponent, this, {
            cfg_showRemovableVolumes: true,
            cfg_showRemovableVolumesDefault: true,
            cfg_openRemovableVolumesInNewTab: true,
            cfg_openRemovableVolumesInNewTabDefault: false
        });
        verify(config);
        compare(config.cfg_showRemovableVolumes, true);
        compare(config.cfg_showRemovableVolumesDefault, true);
        compare(config.cfg_openRemovableVolumesInNewTab, true);
        compare(config.cfg_openRemovableVolumesInNewTabDefault, false);
    }

    function test_acceptsFolderAutoOpenConfiguration() {
        failOnWarning(
            /ConfigGeneral does not have a property called cfg_autoOpenFolderWithOpenDocument/);

        var config = createTemporaryObject(configComponent, this, {
            cfg_showFolderView: true,
            cfg_showFolderViewDefault: true,
            cfg_autoOpenFolderWithOpenDocument: false,
            cfg_autoOpenFolderWithOpenDocumentDefault: true
        });
        verify(config);
        compare(config.cfg_autoOpenFolderWithOpenDocument, false);
        compare(config.cfg_autoOpenFolderWithOpenDocumentDefault, true);
    }

    function test_acceptsAppGroupAutoOpenConfiguration() {
        failOnWarning(
            /ConfigGeneral does not have a property called cfg_autoOpenAppGroupWithRunningApp/);

        var config = createTemporaryObject(configComponent, this, {
            cfg_autoOpenAppGroupWithRunningApp: false,
            cfg_autoOpenAppGroupWithRunningAppDefault: true
        });
        verify(config);
        compare(config.cfg_autoOpenAppGroupWithRunningApp, false);
        compare(config.cfg_autoOpenAppGroupWithRunningAppDefault, true);
    }
}
