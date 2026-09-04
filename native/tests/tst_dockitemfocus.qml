import QtQuick
import QtTest
import "../../contents/ui"

TestCase {
    id: testCase

    name: "DockItemFocus"
    width: 200
    height: 200
    when: windowShown
    visible: true

    property int clickCount: 0
    property int newInstanceCount: 0
    property int contextMenuCount: 0
    property int badgeClickCount: 0

    DockItem {
        id: dockItem
        x: 20
        y: 20
        baseSize: 48
        appName: "Test App"
        onClicked: testCase.clickCount++
        onNewInstanceRequested: testCase.newInstanceCount++
        onContextMenuRequested: testCase.contextMenuCount++
    }

    RecentShareBadge {
        id: shareBadge
        x: 100
        y: 20
        width: 32
        height: 32
        deviceName: "Phone"
        previewText: "photo.jpg"
        onClicked: testCase.badgeClickCount++
    }

    function init() {
        clickCount = 0;
        newInstanceCount = 0;
        contextMenuCount = 0;
        badgeClickCount = 0;
    }

    function test_leftClickDoesNotTakeActiveFocus() {
        verify(!dockItem.activeFocus);
        mouseClick(dockItem, dockItem.width / 2, dockItem.height / 2, Qt.LeftButton);
        compare(clickCount, 1);
        verify(!dockItem.activeFocus);
    }

    function test_middleClickDoesNotTakeActiveFocus() {
        verify(!dockItem.activeFocus);
        mouseClick(dockItem, dockItem.width / 2, dockItem.height / 2, Qt.MiddleButton);
        compare(newInstanceCount, 1);
        verify(!dockItem.activeFocus);
    }

    function test_rightClickDoesNotTakeActiveFocus() {
        verify(!dockItem.activeFocus);
        mouseClick(dockItem, dockItem.width / 2, dockItem.height / 2, Qt.RightButton);
        compare(contextMenuCount, 1);
        verify(!dockItem.activeFocus);
    }

    function test_recentShareBadgeClickDoesNotTakeActiveFocus() {
        verify(!shareBadge.activeFocus);
        mouseClick(shareBadge, shareBadge.width / 2, shareBadge.height / 2, Qt.LeftButton);
        compare(badgeClickCount, 1);
        verify(!shareBadge.activeFocus);
    }
}
