import QtQuick
import QtTest
import "../../contents/ui"

TestCase {
    name: "AddAppsDialog"
    when: windowShown

    Component {
        id: fakeApps

        ListModel {
            property string filter: ""

            ListElement { name: "Alpha"; genericName: "Editor"; comment: ""; icon: "ia"; storageId: "alpha.desktop"; launcherUrl: "applications:alpha.desktop" }
            ListElement { name: "Beta"; genericName: "Player"; comment: ""; icon: "ib"; storageId: "beta.desktop"; launcherUrl: "applications:beta.desktop" }
            ListElement { name: "Gamma"; genericName: ""; comment: "Tool"; icon: "ig"; storageId: "gamma.desktop"; launcherUrl: "applications:gamma.desktop" }
        }
    }

    Component {
        id: dialogComponent

        AddAppsDialog {
            appsModel: fakeApps.createObject(this)
            existingGroups: [{ version: 1, id: "g1", name: "Games", members: [
                { launcher: "applications:x.desktop", name: "x", icon: "i", appId: "x" },
                { launcher: "applications:y.desktop", name: "y", icon: "i", appId: "y" }] }]
            pinnedLaunchers: ["applications:p.desktop"]
        }
    }

    SignalSpy {
        id: planSpy
        signalName: "planReady"
    }

    function openDialog(properties) {
        var dialog = createTemporaryObject(dialogComponent, this, properties || {});
        verify(dialog);
        planSpy.target = dialog;
        planSpy.clear();
        dialog.visible = true;
        return dialog;
    }

    function pick(dialog, id, name) {
        dialog.toggleApp({ launcher: "applications:" + id + ".desktop", name: name, icon: "i" + id, appId: id + ".desktop" });
    }

    function test_oneAppIsAddedWithoutQuestion() {
        var dialog = openDialog();
        pick(dialog, "alpha", "Alpha");
        compare(dialog.selected.length, 1);
        dialog.requestAdd();
        verify(!dialog.confirming);
        compare(planSpy.count, 1);
        var plan = planSpy.signalArguments[0][0];
        compare(plan.addLaunchers, ["applications:alpha.desktop"]);
        compare(plan.groups.length, 1, "only the existing folder, no new one");
        verify(!dialog.visible);
    }

    function test_severalAppsAskWhetherTheyShouldShareAFolder() {
        var dialog = openDialog();
        pick(dialog, "alpha", "Alpha");
        pick(dialog, "beta", "Beta");
        dialog.requestAdd();
        verify(dialog.confirming);
        compare(planSpy.count, 0);
        verify(dialog.visible);
    }

    function test_answeringYesPutsThemAllInOneNamedFolder() {
        var dialog = openDialog();
        pick(dialog, "alpha", "Alpha");
        pick(dialog, "beta", "Beta");
        pick(dialog, "gamma", "Gamma");
        dialog.requestAdd();
        dialog.oneFolderName = "Tools";
        dialog.confirmOneFolder();
        compare(planSpy.count, 1);
        var plan = planSpy.signalArguments[0][0];
        compare(plan.addLaunchers.length, 3);
        compare(plan.groups.length, 2);
        compare(plan.groups[1].name, "Tools");
        compare(plan.groups[1].members.length, 3);
    }

    function test_answeringNoAddsThemSeparately() {
        var dialog = openDialog();
        pick(dialog, "alpha", "Alpha");
        pick(dialog, "beta", "Beta");
        dialog.requestAdd();
        dialog.finish();
        var plan = planSpy.signalArguments[0][0];
        compare(plan.addLaunchers.length, 2);
        compare(plan.groups.length, 1);
        compare(plan.summary.loose, 2);
    }

    function test_sortingIntoFoldersBeforehandSkipsTheQuestion() {
        var dialog = openDialog();
        pick(dialog, "alpha", "Alpha");
        pick(dialog, "beta", "Beta");
        pick(dialog, "gamma", "Gamma");
        var key = dialog.addFolder("Media");
        dialog.assign("applications:alpha.desktop", "new:" + key);
        dialog.assign("applications:beta.desktop", "new:" + key);
        dialog.requestAdd();
        verify(!dialog.confirming);
        var plan = planSpy.signalArguments[0][0];
        compare(plan.groups.length, 2);
        compare(plan.groups[1].name, "Media");
        compare(plan.groups[1].members.length, 2);
        compare(plan.summary.loose, 1);
    }

    function test_appsCanBeSortedIntoAnExistingFolder() {
        var dialog = openDialog();
        pick(dialog, "alpha", "Alpha");
        pick(dialog, "beta", "Beta");
        dialog.assign("applications:alpha.desktop", "group:g1");
        dialog.requestAdd();
        verify(!dialog.confirming);
        var plan = planSpy.signalArguments[0][0];
        compare(plan.groups[0].members.length, 3);
    }

    function test_openingFromAFolderPreselectsIt() {
        var dialog = openDialog({ preferredGroupId: "g1" });
        pick(dialog, "alpha", "Alpha");
        compare(dialog.assignments["applications:alpha.desktop"], "group:g1");
        dialog.requestAdd();
        var plan = planSpy.signalArguments[0][0];
        compare(plan.groups[0].members.length, 3);
    }

    function test_appsAlreadyInTheDockAreRecognised() {
        var dialog = openDialog();
        verify(dialog.isInDock("applications:p.desktop"));
        verify(dialog.isInDock("applications:x.desktop"));
        verify(!dialog.isInDock("applications:alpha.desktop"));
    }

    function test_removingAFolderFreesItsApps() {
        var dialog = openDialog();
        pick(dialog, "alpha", "Alpha");
        pick(dialog, "beta", "Beta");
        var key = dialog.addFolder("Temp");
        dialog.assign("applications:alpha.desktop", "new:" + key);
        dialog.removeFolder(key);
        compare(dialog.newFolders.length, 0);
        compare(dialog.assignments["applications:alpha.desktop"], undefined);
    }

    function test_nothingSelectedDoesNothing() {
        var dialog = openDialog();
        dialog.requestAdd();
        compare(planSpy.count, 0);
        verify(!dialog.confirming);
    }

    function test_reopeningStartsClean() {
        var dialog = openDialog();
        pick(dialog, "alpha", "Alpha");
        dialog.visible = false;
        dialog.visible = true;
        compare(dialog.selected.length, 0);
    }
}
