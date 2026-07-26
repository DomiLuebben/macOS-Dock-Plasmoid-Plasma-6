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
}
