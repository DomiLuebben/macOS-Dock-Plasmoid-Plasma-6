import QtQuick
import QtTest
import "../../contents/ui"

TestCase {
    name: "FolderPopup"

    Component {
        id: fakeFolderModel
        QtObject {
            property string resolvedUrl: ""
            property string iconName: "folder"
            property int sortMode: 6
            property bool sortDesc: false
            property bool showHiddenFiles: false
            property string errorString: ""
            property int upCount: 0
            function up() { ++upCount; }
            function cd() {}
            function run() {}
        }
    }

    Component {
        id: popupComponent
        FolderPopup {}
    }

    function test_atRootFolderHandlesPendingAndEncodedUrls() {
        var model = createTemporaryObject(fakeFolderModel, this);
        var popup = createTemporaryObject(popupComponent, this, {
            folderModel: model,
            rootFolderUrl: "file:///home/user/Meine Ordner"
        });
        verify(popup);

        // Before initial listing finishes, resolvedUrl is empty: must still
        // count as root folder so Back does not escape to parent directories.
        verify(popup.atRootFolder);
        compare(popup.currentFolderName, "Meine Ordner");

        // Percent-encoded resolvedUrl for the same directory must also match.
        model.resolvedUrl = "file:///home/user/Meine%20Ordner/";
        verify(popup.atRootFolder);

        // Navigating into a subdirectory enables Back.
        model.resolvedUrl = "file:///home/user/Meine%20Ordner/Unterordner";
        verify(!popup.atRootFolder);
        compare(popup.currentFolderName, "Unterordner");
    }
}
