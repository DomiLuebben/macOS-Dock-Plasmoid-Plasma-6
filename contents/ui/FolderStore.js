.pragma library

// Pure helpers for the Dock's configured folder list.
//
// Plasma persists folders across three existing keys for compatibility:
//   showFolderView  whether any folder stacks are enabled
//   folderUrl       first folder (empty means defaultFolderUrl when enabled)
//   folderUrls      additional folders after the first
//
// Treating them as a single ordered list lets users add and remove any folder
// (including the default Downloads stack or the last remaining folder) without
// special cases or unexpected fallback resurrections.

function normalizeFolderUrl(value) {
    var raw = String(value || "").trim();
    if (raw.length === 0) {
        return "";
    }
    if (raw.indexOf("/") === 0) {
        raw = "file://" + raw;
    }
    while (raw.length > 1 && raw.endsWith("/") && raw !== "file:///") {
        raw = raw.substring(0, raw.length - 1);
    }
    return raw;
}

function comparableFolderKey(value) {
    var normalized = normalizeFolderUrl(value);
    if (normalized.length === 0) {
        return "";
    }
    try {
        normalized = decodeURI(normalized);
    } catch (error) {
        // Keep malformed escape sequences comparable in raw form.
    }
    while (normalized.length > 1 && normalized.endsWith("/")
            && normalized !== "file:///") {
        normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
}

function displayPath(folderUrl) {
    var key = comparableFolderKey(folderUrl);
    if (key.indexOf("file://") === 0) {
        var path = key.substring(7);
        return path.length > 0 ? path : "/";
    }
    return key;
}

function displayName(folderUrl, fallbackName) {
    var path = displayPath(folderUrl).replace(/\/$/, "");
    if (path === "" && comparableFolderKey(folderUrl) === "file:///") {
        return "/";
    }
    var slash = path.lastIndexOf("/");
    var name = slash >= 0 ? path.substring(slash + 1) : path;
    return name.length > 0 ? name : String(fallbackName || "Folder");
}

function configuredFolders(showFolderView, folderUrl, folderUrls,
        defaultFolderUrl) {
    if (!showFolderView) {
        return [];
    }

    var result = [];
    var seen = {};
    function pushUnique(candidate) {
        var normalized = normalizeFolderUrl(candidate);
        var key = comparableFolderKey(normalized);
        if (key.length === 0 || seen[key]) {
            return;
        }
        seen[key] = true;
        result.push(normalized);
    }

    var primary = normalizeFolderUrl(folderUrl);
    if (primary.length === 0) {
        primary = normalizeFolderUrl(defaultFolderUrl);
    }
    pushUnique(primary);

    var extras = folderUrls || [];
    for (var index = 0; index < extras.length; ++index) {
        pushUnique(extras[index]);
    }
    return result;
}

function toConfiguration(folders, defaultFolderUrl) {
    var unique = [];
    var seen = {};
    var source = folders || [];
    for (var index = 0; index < source.length; ++index) {
        var normalized = normalizeFolderUrl(source[index]);
        var key = comparableFolderKey(normalized);
        if (key.length === 0 || seen[key]) {
            continue;
        }
        seen[key] = true;
        unique.push(normalized);
    }

    if (unique.length === 0) {
        return {
            showFolderView: false,
            folderUrl: "",
            folderUrls: []
        };
    }

    var defaultKey = comparableFolderKey(defaultFolderUrl);
    var firstUrl = comparableFolderKey(unique[0]) === defaultKey
        ? "" : unique[0];

    return {
        showFolderView: true,
        folderUrl: firstUrl,
        folderUrls: unique.slice(1)
    };
}

function addFolders(showFolderView, folderUrl, folderUrls, additions,
        defaultFolderUrl) {
    var current = configuredFolders(
        showFolderView, folderUrl, folderUrls, defaultFolderUrl);
    var seen = {};
    for (var i = 0; i < current.length; ++i) {
        seen[comparableFolderKey(current[i])] = true;
    }

    var next = current.slice();
    var changed = false;
    var addedList = additions || [];
    for (var j = 0; j < addedList.length; ++j) {
        var normalized = normalizeFolderUrl(addedList[j]);
        var key = comparableFolderKey(normalized);
        if (key.length === 0 || seen[key]) {
            continue;
        }
        seen[key] = true;
        next.push(normalized);
        changed = true;
    }

    var config = toConfiguration(next, defaultFolderUrl);
    config.changed = changed;
    return config;
}

function removeFolder(showFolderView, folderUrl, folderUrls, targetUrl,
        defaultFolderUrl) {
    var targetKey = comparableFolderKey(targetUrl);
    var current = configuredFolders(
        showFolderView, folderUrl, folderUrls, defaultFolderUrl);
    if (targetKey.length === 0) {
        var unchanged = toConfiguration(current, defaultFolderUrl);
        unchanged.changed = false;
        return unchanged;
    }

    var next = [];
    var changed = false;
    for (var index = 0; index < current.length; ++index) {
        if (comparableFolderKey(current[index]) === targetKey) {
            changed = true;
        } else {
            next.push(current[index]);
        }
    }

    var config = toConfiguration(next, defaultFolderUrl);
    config.changed = changed;
    return config;
}
