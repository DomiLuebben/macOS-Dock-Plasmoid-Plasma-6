import QtQuick
import QtTest
import "../../contents/ui/BadgeStore.js" as BadgeStore

TestCase {
    name: "BadgeStore"

    function test_labelHidesZeroAndCapsLargeNumbers() {
        compare(BadgeStore.badgeLabel(0), "");
        compare(BadgeStore.badgeLabel(-3), "");
        compare(BadgeStore.badgeLabel("x"), "");
        compare(BadgeStore.badgeLabel(1), "1");
        compare(BadgeStore.badgeLabel(99), "99");
        compare(BadgeStore.badgeLabel(100), "99+");
        compare(BadgeStore.badgeLabel(2500), "99+");
    }

    function test_notificationsCountPerApp() {
        var entries = [
            { appId: "telegram", created: 2000, read: false, userActionFeedback: false },
            { appId: "telegram", created: 3000, read: false, userActionFeedback: false },
            { appId: "signal", created: 2500, read: false, userActionFeedback: false }
        ];
        var counts = BadgeStore.countUnreadNotifications(entries, 1000, {}, {});
        compare(counts.telegram, 2);
        compare(counts.signal, 1);
    }

    function test_oldHistoryFromBeforeTheDockStartedDoesNotCount() {
        var entries = [
            { appId: "telegram", created: 500, read: false, userActionFeedback: false },
            { appId: "telegram", created: 1500, read: false, userActionFeedback: false }
        ];
        var counts = BadgeStore.countUnreadNotifications(entries, 1000, {}, {});
        compare(counts.telegram, 1);
    }

    function test_readAndFeedbackNotificationsAreSkipped() {
        var entries = [
            { appId: "kmix", created: 2000, read: false, userActionFeedback: true },
            { appId: "telegram", created: 2000, read: true, userActionFeedback: false },
            { appId: "", created: 2000, read: false, userActionFeedback: false },
            { appId: "signal", created: NaN, read: false, userActionFeedback: false }
        ];
        compare(Object.keys(BadgeStore.countUnreadNotifications(entries, 1000, {}, {})).length, 0);
    }

    function test_bringingTheAppToTheFrontClearsOlderNotifications() {
        var entries = [
            { appId: "telegram", created: 2000, read: false, userActionFeedback: false },
            { appId: "telegram", created: 4000, read: false, userActionFeedback: false }
        ];
        var counts = BadgeStore.countUnreadNotifications(
            entries, 1000, { telegram: 3000 }, {});
        compare(counts.telegram, 1);
    }

    function test_appInFrontHasNoUnreadMessages() {
        var entries = [
            { appId: "telegram", created: 2000, read: false, userActionFeedback: false }
        ];
        var counts = BadgeStore.countUnreadNotifications(
            entries, 1000, {}, { telegram: true });
        compare(counts.telegram, undefined);
    }

    function test_publishedUnityCountBeatsNotifications() {
        var unity = { telegram: { count: 7, visible: true } };
        var notifications = { telegram: 2 };
        compare(BadgeStore.appBadgeCount(unity, notifications, "telegram"), 7);
    }

    function test_hiddenUnityCountFallsBackToNotifications() {
        var unity = { telegram: { count: 7, visible: false } };
        compare(BadgeStore.appBadgeCount(unity, { telegram: 2 }, "telegram"), 2);
        compare(BadgeStore.appBadgeCount({}, { telegram: 2 }, "telegram"), 2);
        compare(BadgeStore.appBadgeCount({}, {}, "telegram"), 0);
    }

    function test_visibleZeroCountMeansNoBadgeEvenWithNotifications() {
        var unity = { thunderbird: { count: 0, visible: true } };
        compare(BadgeStore.appBadgeCount(unity, { thunderbird: 4 }, "thunderbird"), 0);
    }

    function test_groupSumsItsMembers() {
        compare(BadgeStore.groupBadgeCount([2, 0, 5]), 7);
        compare(BadgeStore.groupBadgeCount([]), 0);
        compare(BadgeStore.groupBadgeCount([-4, "x", 3]), 3);
        compare(BadgeStore.groupBadgeCount(undefined), 0);
    }
}
