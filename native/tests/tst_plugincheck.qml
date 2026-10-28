import QtQuick
import QtTest
import "../../contents/ui"

TestCase {
    name: "PluginCheck"

    Component {
        id: realProbe
        PluginCheck {}
    }

    Component {
        id: pluginWithoutPluginInfo
        // What an older plugin looks like to the probe: the type does not exist.
        PluginCheck {
            probeSource: 'import QtQuick
import "effects" as Effects
Effects.NoSuchType {}'
        }
    }

    Component {
        id: olderPlugin
        PluginCheck {
            probeSource: 'import QtQuick
QtObject { property int apiVersion: 1 }'
        }
    }

    Component {
        id: newerPlugin
        PluginCheck {
            probeSource: 'import QtQuick
QtObject { property int apiVersion: 99 }'
        }
    }

    function test_theBuiltPluginMatchesTheQml() {
        var check = createTemporaryObject(realProbe, this);
        verify(check);
        compare(check.apiVersion, check.requiredApiVersion);
        verify(check.current);
        compare(check.message, "");
    }

    function test_pluginWithoutPluginInfoCountsAsVersionZero() {
        ignoreWarning(new RegExp("native plugin in memory has API version 0"));
        var check = createTemporaryObject(pluginWithoutPluginInfo, this);
        verify(check);
        compare(check.apiVersion, 0);
        verify(!check.current);
        verify(check.message.indexOf("Restart plasmashell") !== -1);
    }

    function test_olderPluginIsReported() {
        ignoreWarning(new RegExp("native plugin in memory has API version 1"));
        var check = createTemporaryObject(olderPlugin, this);
        verify(check);
        compare(check.apiVersion, 1);
        verify(!check.current);
    }

    function test_newerPluginIsAccepted() {
        var check = createTemporaryObject(newerPlugin, this);
        verify(check);
        compare(check.apiVersion, 99);
        verify(check.current);
    }
}
