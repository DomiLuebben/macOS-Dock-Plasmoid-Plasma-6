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

function groupKey(value) {
    return "group:" + String(value || "");
}

function parse(serializedGroups, defaultApplicationName, defaultGroupName) {
    var parsedGroups = [];
    var source = serializedGroups || [];
    var claimedLaunchers = {};
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
        for (var memberIndex = 0;
                memberIndex < parsed.members.length; ++memberIndex) {
            var sourceMember = parsed.members[memberIndex] || {};
            var launcher = normalizeLauncherUrl(
                sourceMember.launcher || "");
            var key = launcherKey(launcher);
            if (!launcher || seenLaunchers[key]
                    || claimedLaunchers[key]) {
                continue;
            }
            seenLaunchers[key] = true;
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
            claimedLaunchers[launcherKey(
                members[claimedIndex].launcher)] = true;
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
    var targetKey = launcherKey(launcherUrl);
    if (targetKey === launcherKey("")) {
        return null;
    }
    for (var groupIndex = 0; groupIndex < groups.length; ++groupIndex) {
        var group = groups[groupIndex];
        for (var memberIndex = 0;
                memberIndex < group.members.length; ++memberIndex) {
            if (launcherKey(group.members[memberIndex].launcher)
                    === targetKey) {
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

function buildLayout(launcherUrls, groups) {
    var groupIdByLauncher = {};
    for (var groupIndex = 0; groupIndex < groups.length; ++groupIndex) {
        var group = groups[groupIndex];
        for (var memberIndex = 0;
                memberIndex < group.members.length; ++memberIndex) {
            groupIdByLauncher[launcherKey(
                group.members[memberIndex].launcher)] = group.id;
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
