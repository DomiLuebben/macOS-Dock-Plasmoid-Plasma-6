import QtQuick
import QtTest
import "../../contents/ui"

TestCase {
    name: "AppGroupPopup"

    Component {
        id: popupComponent

        AppGroupPopup {}
    }

    function test_singleWindowActivatesMember() {
        var popup = createTemporaryObject(popupComponent, this);
        verify(popup);

        var activatedLauncher = "";
        popup.memberActivated.connect(function(launcher) {
            activatedLauncher = launcher;
        });

        popup.activateMember({
            launcher: "applications:single.desktop",
            windows: [{}]
        });

        compare(activatedLauncher, "applications:single.desktop");
        compare(popup.expandedLauncher, "");
    }

    function test_multipleWindowsToggleNestedList() {
        var popup = createTemporaryObject(popupComponent, this);
        verify(popup);

        var activationCount = 0;
        popup.memberActivated.connect(function() {
            ++activationCount;
        });
        var member = {
            launcher: "applications:multi.desktop",
            windows: [{}, {}]
        };
        popup.members = [member];

        popup.activateMember(member);
        compare(popup.expandedLauncher,
            "applications:multi.desktop");
        compare(popup.expandedWindowCount, 2);
        compare(activationCount, 0);

        popup.activateMember(member);
        compare(popup.expandedLauncher, "");
        compare(activationCount, 0);

        popup.activateMember(member);
        compare(popup.expandedLauncher,
            "applications:multi.desktop");
        popup.members = [{
            launcher: "applications:multi.desktop",
            windows: [{}]
        }];
        tryCompare(popup, "expandedLauncher", "");
    }
}
