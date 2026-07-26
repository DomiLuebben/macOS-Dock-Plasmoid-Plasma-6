.pragma library

function normalizeLauncherUrl(value) {
    var launcher = String(value || "").trim();
    var queryIndex = launcher.indexOf("?");
    if (queryIndex >= 0) {
        launcher = launcher.substring(0, queryIndex);
    }
    var fragmentIndex = launcher.indexOf("#");
    if (fragmentIndex >= 0) {
        launcher = launcher.substring(0, fragmentIndex);
    }
    try {
        launcher = decodeURI(launcher);
    } catch (error) {
        // Retain the encoded form; it remains a stable comparison key.
    }
    return launcher;
}

function launcherKey(value) {
    return "launcher:" + normalizeLauncherUrl(value);
}

function normalizeAppId(value) {
    var appId = normalizeLauncherUrl(value);
    appId = appId.replace(/^application:\/\//, "")
        .replace(/^applications:/, "");
    var slashIndex = appId.lastIndexOf("/");
    if (slashIndex >= 0) {
        appId = appId.substring(slashIndex + 1);
    }
    if (appId.toLowerCase().endsWith(".desktop")) {
        appId = appId.substring(0, appId.length - 8);
    }
    return appId.toLowerCase();
}

function appIdKey(value) {
    var appId = normalizeAppId(value);
    return appId ? "app:" + appId : "";
}

function groupKey(value) {
    return "group:" + String(value || "");
}

function parse(serializedGroups, defaultApplicationName, defaultGroupName) {
    var parsedGroups = [];
    var source = serializedGroups || [];
    var claimedLaunchers = {};
    var claimedAppIds = {};
    var seenGroupIds = {};
    for (var groupIndex = 0; groupIndex < source.length; ++groupIndex) {
        var parsed;
        try {
            parsed = JSON.parse(String(source[groupIndex]));
        } catch (error) {
            continue;
        }
        var parsedGroupKey = parsed && parsed.id
            ? groupKey(parsed.id) : "";
        if (!parsed || !parsed.id || !Array.isArray(parsed.members)
                || seenGroupIds[parsedGroupKey]) {
            continue;
        }

        var members = [];
        var seenLaunchers = {};
        var seenAppIds = {};
        for (var memberIndex = 0;
                memberIndex < parsed.members.length; ++memberIndex) {
            var sourceMember = parsed.members[memberIndex] || {};
            var launcher = normalizeLauncherUrl(
                sourceMember.launcher || "");
            var key = launcherKey(launcher);
            var sourceAppIdKey = appIdKey(sourceMember.appId);
            if (!launcher || seenLaunchers[key]
                    || claimedLaunchers[key]
                    || (sourceAppIdKey
                        && (seenAppIds[sourceAppIdKey]
                            || claimedAppIds[sourceAppIdKey]))) {
                continue;
            }
            seenLaunchers[key] = true;
            if (sourceAppIdKey) {
                seenAppIds[sourceAppIdKey] = true;
            }
            members.push({
                launcher: launcher,
                name: String(sourceMember.name
                    || defaultApplicationName),
                icon: String(sourceMember.icon
                    || "application-x-executable"),
                appId: String(sourceMember.appId || "")
            });
        }
        if (members.length < 2) {
            continue;
        }
        seenGroupIds[parsedGroupKey] = true;
        for (var claimedIndex = 0;
                claimedIndex < members.length; ++claimedIndex) {
            var claimedMember = members[claimedIndex];
            claimedLaunchers[launcherKey(
                claimedMember.launcher)] = true;
            var claimedAppIdKey = appIdKey(claimedMember.appId);
            if (claimedAppIdKey) {
                claimedAppIds[claimedAppIdKey] = true;
            }
        }
        parsedGroups.push({
            version: 1,
            id: String(parsed.id),
            name: String(parsed.name || defaultGroupName),
            members: members
        });
    }
    return parsedGroups;
}

function serialize(groups) {
    var result = [];
    for (var index = 0; index < groups.length; ++index) {
        result.push(JSON.stringify(groups[index]));
    }
    return result;
}

function findGroupForLauncher(groups, launcherUrl) {
    return findGroupForIdentity(groups, launcherUrl, "");
}

function findGroupForIdentity(groups, launcherUrl, appId) {
    var targetLauncherKey = launcherKey(launcherUrl);
    var targetAppIdKey = appIdKey(appId);
    if (targetLauncherKey === launcherKey("") && !targetAppIdKey) {
        return null;
    }
    for (var groupIndex = 0; groupIndex < groups.length; ++groupIndex) {
        var group = groups[groupIndex];
        for (var memberIndex = 0;
                memberIndex < group.members.length; ++memberIndex) {
            var member = group.members[memberIndex];
            if (launcherKey(member.launcher) === targetLauncherKey
                    || (targetAppIdKey
                        && appIdKey(member.appId) === targetAppIdKey)) {
                return group;
            }
        }
    }
    return null;
}

function findGroupById(groups, groupId) {
    var target = String(groupId || "");
    for (var index = 0; index < groups.length; ++index) {
        if (groups[index].id === target) {
            return groups[index];
        }
    }
    return null;
}

function buildLayout(launcherUrls, groups, appIds) {
    var groupIdByLauncher = {};
    var groupIdByAppId = {};
    for (var groupIndex = 0; groupIndex < groups.length; ++groupIndex) {
        var group = groups[groupIndex];
        for (var memberIndex = 0;
                memberIndex < group.members.length; ++memberIndex) {
            var member = group.members[memberIndex];
            groupIdByLauncher[launcherKey(member.launcher)] = group.id;
            var memberAppIdKey = appIdKey(member.appId);
            if (memberAppIdKey) {
                groupIdByAppId[memberAppIdKey] = group.id;
            }
        }
    }

    var visualByRow = [];
    var modelByVisual = [];
    var groupIdByRow = [];
    var leaderRowByGroup = {};
    var seenGroups = {};
    var visualIndex = -1;

    for (var row = 0; row < launcherUrls.length; ++row) {
        var groupId = groupIdByLauncher[
            launcherKey(launcherUrls[row])] || "";
        if (!groupId && appIds && row < appIds.length) {
            groupId = groupIdByAppId[appIdKey(appIds[row])] || "";
        }
        var keyedGroupId = groupKey(groupId);
        groupIdByRow.push(groupId);
        if (groupId && seenGroups[keyedGroupId] !== undefined) {
            visualByRow.push(seenGroups[keyedGroupId]);
            continue;
        }

        ++visualIndex;
        visualByRow.push(visualIndex);
        modelByVisual.push(row);
        if (groupId) {
            seenGroups[keyedGroupId] = visualIndex;
            leaderRowByGroup[keyedGroupId] = row;
        }
    }

    return {
        visualByRow: visualByRow,
        modelByVisual: modelByVisual,
        groupIdByRow: groupIdByRow,
        leaderRowByGroup: leaderRowByGroup
    };
}

function isLeader(layout, row, groupId) {
    return Boolean(groupId)
        && layout.leaderRowByGroup[groupKey(groupId)] === row;
}

function visualIndexForDrag(stableIndex, originIndex, targetIndex,
        groupingActive) {
    // A centered group drop is an overlay gesture: both launcher slots stay
    // in place while the dragged icon moves via its pointer offset.
    if (groupingActive || targetIndex < 0) {
        return stableIndex;
    }
    if (stableIndex === originIndex) {
        return targetIndex;
    }
    if (targetIndex > originIndex
            && stableIndex > originIndex
            && stableIndex <= targetIndex) {
        return stableIndex - 1;
    }
    if (targetIndex < originIndex
            && stableIndex >= targetIndex
            && stableIndex < originIndex) {
        return stableIndex + 1;
    }
    return stableIndex;
}

function stableIndexForDragVisual(visualIndex, originIndex, targetIndex,
        groupingActive) {
    if (groupingActive || targetIndex < 0) {
        return visualIndex;
    }
    if (visualIndex === targetIndex) {
        return originIndex;
    }
    if (targetIndex > originIndex
            && visualIndex >= originIndex
            && visualIndex < targetIndex) {
        return visualIndex + 1;
    }
    if (targetIndex < originIndex
            && visualIndex > targetIndex
            && visualIndex <= originIndex) {
        return visualIndex - 1;
    }
    return visualIndex;
}
