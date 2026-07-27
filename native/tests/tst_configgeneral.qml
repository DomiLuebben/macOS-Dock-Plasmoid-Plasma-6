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
            cfg_magnificationSpring: 12.5,
            cfg_magnificationSpringDefault: 10.0,
            cfg_magnificationDamping: 0.75,
            cfg_magnificationDampingDefault: 0.8,
            cfg_clickBounceHeight: 5,
            cfg_clickBounceHeightDefault: 4,
            cfg_launchBounceHeight: 10,
            cfg_launchBounceHeightDefault: 8,
            cfg_dockRevealDuration: 220,
            cfg_dockRevealDurationDefault: 240,
            cfg_dockHideDuration: 250,
            cfg_dockHideDurationDefault: 280,
            cfg_appGroupPopupDuration: 280,
            cfg_appGroupPopupDurationDefault: 260,
            cfg_appGroupPopupOvershoot: 1.5,
            cfg_appGroupPopupOvershootDefault: 1.35,
            cfg_folderHoverScale: 1.08,
            cfg_folderHoverScaleDefault: 1.06
        });
        verify(config);
        compare(config.cfg_magnificationSpring, 12.5);
        compare(config.cfg_magnificationDamping, 0.75);
        compare(config.cfg_clickBounceHeight, 5);
        compare(config.cfg_launchBounceHeight, 10);
        compare(config.cfg_dockRevealDuration, 220);
        compare(config.cfg_dockHideDuration, 250);
        compare(config.cfg_appGroupPopupDuration, 280);
        compare(config.cfg_appGroupPopupOvershoot, 1.5);
        compare(config.cfg_folderHoverScale, 1.08);
    }
}
