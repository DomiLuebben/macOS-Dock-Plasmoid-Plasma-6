.pragma library

// Pure helpers for the unread badges. Everything here is free of QML types so
// the rules can be unit-tested without a running shell.

// Largest number shown on a badge; anything above reads "99+".
var MAX_DISPLAY = 99;

function badgeLabel(count) {
    var value = Math.floor(Number(count));
    if (!isFinite(value) || value <= 0) {
        return "";
    }
    return value > MAX_DISPLAY ? MAX_DISPLAY + "+" : String(value);
}

// Counts the unread notifications per application.
//
// A notification counts while it is still in the history, nobody marked it as
// read, it was not just feedback for something the user did (volume OSD,
// screenshot confirmation), and it arrived after the dock started and after
// the user last brought that application to the front. Notifications that
// were already in the history when the dock started would otherwise put a
// stale badge on every chat client after each shell restart.
//
// An application that is in front right now cannot have unread messages: the
// user is looking at it.
//
// entries:    [{ appId, created (ms since epoch), read, userActionFeedback }]
// seenAt:     { appId: ms since epoch }
// activeApps: { appId: true }
// Returns { appId: count }.
function countUnreadNotifications(entries, baselineMs, seenAt, activeApps) {
    var counts = {};
    var seen = seenAt || {};
    var active = activeApps || {};
    for (var index = 0; index < (entries ? entries.length : 0); ++index) {
        var entry = entries[index];
        if (!entry || !entry.appId || entry.read || entry.userActionFeedback
                || active[entry.appId]) {
            continue;
        }
        var created = Number(entry.created);
        if (!isFinite(created)) {
            continue;
        }
        var floor = Math.max(Number(baselineMs) || 0,
            Number(seen[entry.appId]) || 0);
        if (created <= floor) {
            continue;
        }
        counts[entry.appId] = (counts[entry.appId] || 0) + 1;
    }
    return counts;
}

// The count one application shows. An application that publishes its own
// count over the Unity launcher API knows best; its number wins. Notifications
// are the fallback for applications that only send notifications.
//
// unity: { appId: { count, visible } }
function appBadgeCount(unity, notifications, appId) {
    var published = unity ? unity[appId] : undefined;
    if (published && published.visible) {
        return Math.max(0, Math.floor(Number(published.count) || 0));
    }
    return Math.max(0, Math.floor(Number(
        notifications ? notifications[appId] : 0) || 0));
}

// Sum over the members of a group (the folder on the dock).
function groupBadgeCount(counts) {
    var total = 0;
    for (var index = 0; index < (counts ? counts.length : 0); ++index) {
        total += Math.max(0, Math.floor(Number(counts[index]) || 0));
    }
    return total;
}
