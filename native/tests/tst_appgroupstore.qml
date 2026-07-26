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

    function test_appIdentitySurvivesLauncherStateChanges() {
        var groups = AppGroupStore.parse([
            JSON.stringify({
                id: "assistants",
                name: "AI",
                members: [
                    {
                        launcher: "applications:Codex.desktop",
                        name: "Codex",
                        appId: "Codex.desktop"
                    },
                    {
                        launcher:
                            "applications:com.anthropic.Claude.desktop",
                        name: "Claude",
                        appId: "com.anthropic.Claude.desktop"
                    }
                ]
            })
        ], "Application", "Group");

        // A closed LauncherTasksModel row can expose only the resolved desktop
        // file URL and no AppId at all.
        var closedLayout = AppGroupStore.buildLayout([
            "file:///usr/share/applications/Codex.desktop",
            "file:///usr/share/applications/com.anthropic.Claude.desktop"
        ], groups, ["", ""]);
        compare(closedLayout.modelByVisual.length, 1);
        compare(AppGroupStore.findGroupForIdentity(groups,
            "file:///usr/share/applications/Codex.desktop", "").id,
            "assistants");

        // Plasma may expose another launcher URL after replacing a pinned,
        // closed launcher row with the running task. The desktop app ID stays
        // stable and must retain the group membership.
        var runningLayout = AppGroupStore.buildLayout([
            "applications:org.openai.Codex.desktop",
            "applications:Claude.desktop"
        ], groups, [
            "Codex.desktop",
            "com.anthropic.Claude.desktop"
        ]);
        compare(runningLayout.modelByVisual.length, 1);
        compare(runningLayout.groupIdByRow[0], "assistants");
        compare(runningLayout.groupIdByRow[1], "assistants");
        compare(AppGroupStore.findGroupForIdentity(groups,
            "applications:org.openai.Codex.desktop",
            "Codex.desktop").id, "assistants");
    }

    function test_appIdsAreNormalizedAndStayUnambiguous() {
        compare(AppGroupStore.normalizeAppId(
            "applications:Org.Kde.Konsole.desktop?icon=x"),
            "org.kde.konsole");

        var duplicateIdentity = JSON.stringify({
            id: "duplicate-identity",
            members: [
                {
                    launcher: "applications:first.desktop",
                    appId: "same.desktop"
                },
                {
                    launcher: "applications:second.desktop",
                    appId: "SAME"
                }
            ]
        });
        compare(AppGroupStore.parse(
            [duplicateIdentity], "Application", "Group").length, 0);
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

    function test_centeredGroupDropKeepsBothSlotsStable() {
        // Claude (14) is dragged left onto Codex (13). During grouping,
        // Codex must not be shifted away by the normal reorder preview.
        compare(AppGroupStore.visualIndexForDrag(
            14, 14, 13, true), 14);
        compare(AppGroupStore.visualIndexForDrag(
            13, 14, 13, true), 13);
        compare(AppGroupStore.stableIndexForDragVisual(
            13, 14, 13, true), 13);

        // The same path outside the centered drop zone remains a reorder.
        compare(AppGroupStore.visualIndexForDrag(
            14, 14, 13, false), 13);
        compare(AppGroupStore.visualIndexForDrag(
            13, 14, 13, false), 14);
    }
}
