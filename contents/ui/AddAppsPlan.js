.pragma library
.import "AppGroupStore.js" as Store

// Turns the choices made in the "Add Apps" picker into the two things the dock
// stores: the launchers to pin and the folder (app group) list. Pure functions,
// no QML types, so the rules are unit-tested.
//
// apps:         [{ launcher, name, icon, appId }] in the order they were picked
// assignments:  { <launcher url>: target } where target is
//                 ""                 add to the dock on its own
//                 "new:<key>"        into the new folder with that key
//                 "group:<group id>" into an existing folder
// newFolders:   [{ key, name }]
// groups:       the dock's current folders (AppGroupStore.parse result)
// pinned:       launcher urls already in the dock
// makeId:       () => string, injectable for tests

function newGroupId() {
    return "group-" + Date.now().toString(36) + "-"
        + Math.floor(Math.random() * 1679616).toString(36);
}

function isPinned(pinned, launcher) {
    var key = Store.launcherKey(launcher);
    for (var index = 0; index < (pinned ? pinned.length : 0); ++index) {
        if (Store.launcherKey(pinned[index]) === key) {
            return true;
        }
    }
    return false;
}

function memberOf(app) {
    return {
        launcher: Store.normalizeLauncherUrl(app.launcher),
        name: String(app.name || ""),
        icon: String(app.icon || "application-x-executable"),
        appId: String(app.appId || "")
    };
}

function buildPlan(apps, assignments, newFolders, groups, pinned, makeId) {
    var idFor = makeId || newGroupId;
    var assigned = assignments || {};
    var seen = {};
    var addLaunchers = [];
    var loose = [];
    var membersByNew = {};
    var membersByGroup = {};

    for (var index = 0; index < (apps ? apps.length : 0); ++index) {
        var app = apps[index];
        var launcher = Store.normalizeLauncherUrl(app && app.launcher);
        var key = Store.launcherKey(launcher);
        // Nothing twice, nothing that is already in the dock or in a folder.
        if (!launcher || seen[key] || isPinned(pinned, launcher)
                || Store.findGroupForLauncher(groups || [], launcher)) {
            continue;
        }
        seen[key] = true;
        addLaunchers.push(launcher);

        var target = String(assigned[app.launcher] || assigned[launcher] || "");
        if (target.indexOf("new:") === 0) {
            var newKey = target.substring(4);
            (membersByNew[newKey] = membersByNew[newKey] || []).push(app);
        } else if (target.indexOf("group:") === 0
                && Store.findGroupById(groups || [], target.substring(6))) {
            var groupId = target.substring(6);
            (membersByGroup[groupId] = membersByGroup[groupId] || []).push(app);
        } else {
            loose.push(app);
        }
    }

    var nextGroups = [];
    for (var groupIndex = 0; groupIndex < (groups ? groups.length : 0); ++groupIndex) {
        var group = groups[groupIndex];
        var extra = membersByGroup[group.id] || [];
        var members = group.members.slice();
        for (var extraIndex = 0; extraIndex < extra.length; ++extraIndex) {
            members.push(memberOf(extra[extraIndex]));
        }
        nextGroups.push({
            version: 1,
            id: group.id,
            name: group.name,
            members: members
        });
    }

    // A folder needs at least two apps. A new folder that ended up with one
    // app is not created; its app is pinned on its own instead.
    var createdFolders = [];
    var singleFolders = [];
    for (var folderIndex = 0; folderIndex < (newFolders ? newFolders.length : 0); ++folderIndex) {
        var folder = newFolders[folderIndex];
        var inFolder = membersByNew[folder.key] || [];
        if (inFolder.length >= 2) {
            var folderMembers = [];
            for (var m = 0; m < inFolder.length; ++m) {
                folderMembers.push(memberOf(inFolder[m]));
            }
            nextGroups.push({
                version: 1,
                id: idFor(),
                name: String(folder.name || "").trim(),
                members: folderMembers
            });
            createdFolders.push({ name: String(folder.name || "").trim(), count: inFolder.length });
        } else if (inFolder.length === 1) {
            loose.push(inFolder[0]);
            singleFolders.push(String(folder.name || ""));
        }
    }
    // Apps pointing at a new-folder key that does not exist are pinned loose.
    for (var orphanKey in membersByNew) {
        var known = false;
        for (var k = 0; k < (newFolders ? newFolders.length : 0); ++k) {
            if (newFolders[k].key === orphanKey) {
                known = true;
            }
        }
        if (!known) {
            for (var o = 0; o < membersByNew[orphanKey].length; ++o) {
                loose.push(membersByNew[orphanKey][o]);
            }
        }
    }

    return {
        addLaunchers: addLaunchers,
        groups: nextGroups,
        summary: {
            added: addLaunchers.length,
            loose: loose.length,
            folders: createdFolders,
            intoExisting: Object.keys(membersByGroup).length,
            singleFolders: singleFolders
        }
    };
}

// Every picked app into one new folder.
function allInOneFolder(apps, folderKey) {
    var assignments = {};
    for (var index = 0; index < (apps ? apps.length : 0); ++index) {
        assignments[apps[index].launcher] = "new:" + folderKey;
    }
    return assignments;
}

// True when at least one picked app was already given a folder.
function hasFolderChoice(apps, assignments) {
    for (var index = 0; index < (apps ? apps.length : 0); ++index) {
        var target = String((assignments || {})[apps[index].launcher] || "");
        if (target.length > 0) {
            return true;
        }
    }
    return false;
}
