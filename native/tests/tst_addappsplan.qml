import QtQuick
import QtTest
import "../../contents/ui/AddAppsPlan.js" as Plan

TestCase {
    name: "AddAppsPlan"

    function app(id, name) {
        return { launcher: "applications:" + id + ".desktop", name: name || id,
            icon: "icon-" + id, appId: id + ".desktop" };
    }

    function nextId() {
        return "gid-" + (++nextId.n);
    }

    function init() {
        nextId.n = 0;
    }

    function test_looseAppsAreJustPinned() {
        var plan = Plan.buildPlan([app("a"), app("b")], {}, [], [], [], nextId);
        compare(plan.addLaunchers.length, 2);
        compare(plan.groups.length, 0);
        compare(plan.summary.loose, 2);
    }

    function test_twoAppsInANewFolderMakeAGroup() {
        var apps = [app("a"), app("b"), app("c")];
        var assignments = { "applications:a.desktop": "new:f1", "applications:b.desktop": "new:f1" };
        var plan = Plan.buildPlan(apps, assignments, [{ key: "f1", name: "  Office " }], [], [], nextId);
        compare(plan.addLaunchers.length, 3);
        compare(plan.groups.length, 1);
        compare(plan.groups[0].name, "Office");
        compare(plan.groups[0].id, "gid-1");
        compare(plan.groups[0].members.length, 2);
        compare(plan.groups[0].members[0].launcher, "applications:a.desktop");
        compare(plan.groups[0].members[0].icon, "icon-a");
        compare(plan.summary.loose, 1);
        compare(plan.summary.folders[0].count, 2);
    }

    function test_aNewFolderWithOneAppIsNotCreated() {
        var plan = Plan.buildPlan([app("a"), app("b")],
            { "applications:a.desktop": "new:f1" }, [{ key: "f1", name: "Solo" }], [], [], nextId);
        compare(plan.groups.length, 0);
        compare(plan.addLaunchers.length, 2);
        compare(plan.summary.loose, 2);
        compare(plan.summary.singleFolders[0], "Solo");
    }

    function test_appsCanJoinAnExistingFolder() {
        var groups = [{ version: 1, id: "g1", name: "Games", members: [
            { launcher: "applications:x.desktop", name: "x", icon: "i", appId: "x" },
            { launcher: "applications:y.desktop", name: "y", icon: "i", appId: "y" }] }];
        var plan = Plan.buildPlan([app("a")], { "applications:a.desktop": "group:g1" }, [], groups, [], nextId);
        compare(plan.groups.length, 1);
        compare(plan.groups[0].members.length, 3);
        compare(plan.groups[0].members[2].launcher, "applications:a.desktop");
        compare(plan.summary.intoExisting, 1);
        compare(plan.summary.loose, 0);
    }

    function test_existingFolderIsLeftUntouchedWhenNothingJoins() {
        var groups = [{ version: 1, id: "g1", name: "Games", members: [
            { launcher: "applications:x.desktop", name: "x", icon: "i", appId: "x" },
            { launcher: "applications:y.desktop", name: "y", icon: "i", appId: "y" }] }];
        var plan = Plan.buildPlan([app("a")], {}, [], groups, [], nextId);
        compare(plan.groups.length, 1);
        compare(plan.groups[0].members.length, 2);
    }

    function test_appsAlreadyInTheDockOrInAFolderAreSkipped() {
        var groups = [{ version: 1, id: "g1", name: "G", members: [
            { launcher: "applications:x.desktop", name: "x", icon: "i", appId: "x" },
            { launcher: "applications:y.desktop", name: "y", icon: "i", appId: "y" }] }];
        var plan = Plan.buildPlan([app("a"), app("x"), app("p")], {}, [], groups,
            ["applications:p.desktop"], nextId);
        compare(plan.addLaunchers.length, 1);
        compare(plan.addLaunchers[0], "applications:a.desktop");
    }

    function test_theSameAppTwiceCountsOnce() {
        var plan = Plan.buildPlan([app("a"), app("a")], {}, [], [], [], nextId);
        compare(plan.addLaunchers.length, 1);
    }

    function test_unknownTargetsFallBackToLoose() {
        var plan = Plan.buildPlan([app("a")], { "applications:a.desktop": "group:gone" }, [], [], [], nextId);
        compare(plan.summary.loose, 1);
        compare(plan.groups.length, 0);
        plan = Plan.buildPlan([app("a")], { "applications:a.desktop": "new:nope" }, [], [], [], nextId);
        compare(plan.summary.loose, 1);
    }

    function test_allInOneFolderAssignsEveryApp() {
        var apps = [app("a"), app("b"), app("c")];
        var assignments = Plan.allInOneFolder(apps, "f9");
        var plan = Plan.buildPlan(apps, assignments, [{ key: "f9", name: "Tools" }], [], [], nextId);
        compare(plan.groups.length, 1);
        compare(plan.groups[0].members.length, 3);
        compare(plan.summary.loose, 0);
    }

    function test_hasFolderChoice() {
        var apps = [app("a"), app("b")];
        verify(!Plan.hasFolderChoice(apps, {}));
        verify(!Plan.hasFolderChoice(apps, { "applications:a.desktop": "" }));
        verify(Plan.hasFolderChoice(apps, { "applications:b.desktop": "new:f1" }));
    }

    function test_resultSurvivesTheStoreParser() {
        // What gets saved must be accepted by the parser the dock reads it back with.
        var apps = [app("a"), app("b")];
        var plan = Plan.buildPlan(apps, Plan.allInOneFolder(apps, "f"), [{ key: "f", name: "F" }], [], [], nextId);
        var json = [];
        for (var i = 0; i < plan.groups.length; ++i) {
            json.push(JSON.stringify(plan.groups[i]));
        }
        compare(Plan.buildPlan([], {}, [], [], [], nextId).groups.length, 0);
        compare(json.length, 1);
        compare(JSON.parse(json[0]).members.length, 2);
    }
}
