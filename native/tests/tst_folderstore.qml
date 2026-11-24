import QtQuick
import QtTest
import "../../contents/ui"
import "../../contents/ui/FolderStore.js" as FolderStore

TestCase {
    name: "FolderStore"

    readonly property string downloadsUrl: "file:///home/user/Downloads"

    Component {
        id: presenceComponent

        FolderPresenceController {
            pluginApiVersion: 0
        }
    }

    function test_configuredFoldersCombinesDefaultAndExtras() {
        var list = FolderStore.configuredFolders(
            true,
            "",
            ["file:///OneTouch/Nextcloud", "file:///home/user/Downloads/"],
            downloadsUrl);
        compare(list, [
            "file:///home/user/Downloads",
            "file:///OneTouch/Nextcloud"
        ]);
    }

    function test_configuredFoldersEmptyWhenDisabled() {
        var list = FolderStore.configuredFolders(
            false,
            "file:///home/user/Documents",
            ["file:///OneTouch/Nextcloud"],
            downloadsUrl);
        compare(list, []);
    }

    function test_removeSecondaryFolderKeepsDownloadsDefault() {
        var result = FolderStore.removeFolder(
            true,
            "",
            ["file:///OneTouch/Nextcloud"],
            "file:///OneTouch/Nextcloud/",
            downloadsUrl);
        compare(result.changed, true);
        compare(result.showFolderView, true);
        compare(result.folderUrl, "");
        compare(result.folderUrls, []);
    }

    function test_removePrimaryFolderPromotesSecondFolder() {
        var result = FolderStore.removeFolder(
            true,
            "",
            ["file:///home/user/Documents", "file:///home/user/Pictures"],
            downloadsUrl,
            downloadsUrl);
        compare(result.changed, true);
        compare(result.showFolderView, true);
        compare(result.folderUrl, "file:///home/user/Documents");
        compare(result.folderUrls, ["file:///home/user/Pictures"]);
    }

    function test_removeLastFolderDisablesViewWithoutResurrectingDefault() {
        var removed = FolderStore.removeFolder(
            true,
            "",
            [],
            downloadsUrl,
            downloadsUrl);
        compare(removed.changed, true);
        compare(removed.showFolderView, false);
        compare(removed.folderUrl, "");
        compare(removed.folderUrls, []);

        var added = FolderStore.addFolders(
            removed.showFolderView,
            removed.folderUrl,
            removed.folderUrls,
            ["/home/user/Projects/"],
            downloadsUrl);
        compare(added.changed, true);
        compare(added.showFolderView, true);
        compare(added.folderUrl, "file:///home/user/Projects");
        compare(added.folderUrls, []);
    }

    function test_presenceControllerFiltersWithFallbackAndMockWatcher() {
        failOnWarning(/Binding loop/);

        var controller = createTemporaryObject(presenceComponent, this, {
            watchedUrls: [
                "file:///tmp",
                "file:///OneTouch/Nextcloud"
            ],
            fallbackExistsFn: function (url) {
                return url === "file:///tmp";
            }
        });
        verify(controller);
        compare(controller.existingUrls, ["file:///tmp"]);
        compare(controller.directoryExists("file:///tmp"), true);
        compare(controller.directoryExists("file:///OneTouch/Nextcloud"), false);

        // Upgrading pluginApiVersion to activate the native FolderWatcher must
        // not trigger any QML binding loops and must keep missing paths hidden.
        controller.pluginApiVersion = 5;
        compare(controller.existingUrls, ["file:///tmp"]);
        compare(controller.directoryExists("file:///tmp"), true);
        compare(controller.directoryExists("file:///OneTouch/Nextcloud"), false);
    }
}
