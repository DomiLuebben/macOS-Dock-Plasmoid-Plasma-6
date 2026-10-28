import QtQuick
import QtTest
import "../../contents/ui"

TestCase {
    id: testCase

    name: "DockItemBadge"
    width: 240
    height: 160
    when: windowShown
    visible: true

    DockItem {
        id: appItem
        x: 40
        y: 40
        baseSize: 48
        appName: "Chat"
    }

    DockItem {
        id: folderItem
        x: 140
        y: 40
        baseSize: 48
        appName: "Messaging"
        isAppGroup: true
        groupPreviewItems: [{ icon: "internet-mail" }, { icon: "dialog-messages" }]
    }

    function init() {
        appItem.badgeCount = 0;
        folderItem.badgeCount = 0;
        appItem.hasRecentShare = false;
    }

    function badgeOf(item) {
        return findChild(item, "unreadBadge");
    }

    function test_noBadgeWithoutUnreadMessages() {
        compare(appItem.badgeCount, 0);
        verify(!badgeOf(appItem) || !badgeOf(appItem).visible);
    }

    function test_appShowsItsCount() {
        appItem.badgeCount = 3;
        tryVerify(function() { return badgeOf(appItem) !== null; });
        compare(badgeOf(appItem).label, "3");
        verify(badgeOf(appItem).visible);
    }

    function test_closedFolderShowsTheBadgeOnTheFolderIcon() {
        folderItem.badgeCount = 12;
        tryVerify(function() { return badgeOf(folderItem) !== null; });
        var badge = badgeOf(folderItem);
        compare(badge.label, "12");
        // On the icon itself, reaching past its top-right corner.
        verify(badge.mapToItem(folderItem, 0, 0).y < folderItem.height * 0.3);
        verify(badge.mapToItem(folderItem, badge.width, 0).x > folderItem.width * 0.8);
    }

    function test_largeCountsAreCapped() {
        folderItem.badgeCount = 250;
        tryVerify(function() { return badgeOf(folderItem) !== null; });
        compare(badgeOf(folderItem).label, "99+");
    }

    function test_badgeStepsAsideForTheSharingBadge() {
        appItem.badgeCount = 2;
        appItem.hasRecentShare = true;
        appItem.recentShareUrl = "https://example.org";
        tryVerify(function() { return badgeOf(appItem) !== null; });
        verify(badgeOf(appItem).onLeft);
        appItem.recentShareUrl = "";
    }

    function test_badgeDisappearsWhenCountIsCleared() {
        appItem.badgeCount = 4;
        tryVerify(function() { return badgeOf(appItem) !== null; });
        appItem.badgeCount = 0;
        tryVerify(function() { return badgeOf(appItem) === null; });
    }
}
