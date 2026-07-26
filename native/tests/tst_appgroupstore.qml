import QtQuick
import QtTest
import "../../contents/ui/AppGroupStore.js" as AppGroupStore

TestCase {
    name: "AppGroupStore"

    readonly property var serializedGroup: JSON.stringify({
        version: 1,
        id: "browsers",
        name: "Browsers",
        members: [
            {
                launcher: "applications:firefox.desktop?iconData=ignored",
                name: "Firefox",
                icon: "firefox",
                appId: "firefox"
            },
            {
                launcher: "applications:chromium.desktop",
                name: "Chromium",
                icon: "chromium",
                appId: "chromium"
            }
        ]
    })

    function test_parseSanitizesAndRoundTrips() {
        var groups = AppGroupStore.parse([
            "{malformed",
            serializedGroup
        ], "Application", "Group");

        compare(groups.length, 1);
        compare(groups[0].members.length, 2);
        compare(groups[0].members[0].launcher,
            "applications:firefox.desktop");

        var roundTrip = AppGroupStore.parse(
            AppGroupStore.serialize(groups), "Application", "Group");
        compare(roundTrip.length, 1);
        compare(roundTrip[0].name, "Browsers");
    }

    function test_layoutCollapsesMembersIntoOneSlot() {
        var groups = AppGroupStore.parse(
            [serializedGroup], "Application", "Group");
        var layout = AppGroupStore.buildLayout([
            "applications:firefox.desktop",
            "applications:org.kde.dolphin.desktop",
            "applications:chromium.desktop",
            "applications:org.kde.kate.desktop"
        ], groups);

        compare(layout.modelByVisual.length, 3);
        compare(layout.visualByRow[0], 0);
        compare(layout.visualByRow[1], 1);
        compare(layout.visualByRow[2], 0);
        compare(layout.visualByRow[3], 2);
        compare(layout.modelByVisual[0], 0);
        verify(AppGroupStore.isLeader(layout, 0, "browsers"));
        verify(!AppGroupStore.isLeader(layout, 2, "browsers"));
    }

    function test_duplicateAndSingleMemberGroupsAreRejected() {
        var duplicateGroup = JSON.stringify({
            id: "invalid",
            members: [
                { launcher: "applications:firefox.desktop" },
                { launcher: "applications:firefox.desktop?x=1" }
            ]
        });
        compare(AppGroupStore.parse(
            [duplicateGroup], "Application", "Group").length, 0);
    }

    function test_duplicateMembershipAndIdsStayUnambiguous() {
        var firstGroup = JSON.stringify({
            id: "first",
            members: [
                { launcher: "applications:a.desktop" },
                { launcher: "applications:b.desktop" }
            ]
        });
        var overlappingGroup = JSON.stringify({
            id: "second",
            members: [
                { launcher: "applications:b.desktop" },
                { launcher: "applications:c.desktop" }
            ]
        });
        var duplicateId = JSON.stringify({
            id: "first",
            members: [
                { launcher: "applications:d.desktop" },
                { launcher: "applications:e.desktop" }
            ]
        });

        var groups = AppGroupStore.parse([
            firstGroup,
            overlappingGroup,
            duplicateId
        ], "Application", "Group");
        compare(groups.length, 1);
        compare(groups[0].id, "first");
    }
}
