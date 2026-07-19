pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.layershell as LayerShell
import org.kde.plasma.core as PlasmaCore
import org.kde.private.desktopcontainment.folder as Folder
import "effects" as DockEffects

Window {
    id: root

    property var folderModel: null
    property Item visualParent: null
    property url rootFolderUrl: ""
    property int location: PlasmaCore.Types.BottomEdge
    property real screenEdgeMargin: 0
    property real surfaceOpacity: 0.82
    property bool useThemeColor: true
    property color customColor: "#20242b"
    property real requestedRadius: 18
    property real borderOpacity: 0.22
    property real shadowOpacity: 0.42
    property bool showHighlight: true
    property bool blurEnabled: true
    readonly property bool isVertical:
        location === PlasmaCore.Types.LeftEdge
        || location === PlasmaCore.Types.RightEdge
    readonly property bool hovered: popupHover.hovered
    readonly property string currentFolderName:
        folderName(folderModel ? folderModel.resolvedUrl : rootFolderUrl)
    readonly property bool atRootFolder:
        normalizedUrl(folderModel ? folderModel.resolvedUrl : "")
            === normalizedUrl(rootFolderUrl)

    property real placementLeft: 0
    property real placementTop: 0
    property real placementRight: 0
    property real placementBottom: 0

    signal openFolderRequested(url folderUrl)

    width: 440
    height: Math.min(560, screen ? screen.height - 32 : 560)
    minimumWidth: 340
    minimumHeight: 360
    flags: Qt.FramelessWindowHint
    color: "transparent"
    visible: false

    LayerShell.Window.scope: "macosdock-folder-popup"
    LayerShell.Window.anchors: {
        if (root.location === PlasmaCore.Types.LeftEdge) {
            return LayerShell.Window.AnchorLeft
                | LayerShell.Window.AnchorTop;
        }
        if (root.location === PlasmaCore.Types.RightEdge) {
            return LayerShell.Window.AnchorRight
                | LayerShell.Window.AnchorTop;
        }
        if (root.location === PlasmaCore.Types.TopEdge) {
            return LayerShell.Window.AnchorLeft
                | LayerShell.Window.AnchorTop;
        }
        return LayerShell.Window.AnchorLeft
            | LayerShell.Window.AnchorBottom;
    }
    LayerShell.Window.margins.left: placementLeft
    LayerShell.Window.margins.top: placementTop
    LayerShell.Window.margins.right: placementRight
    LayerShell.Window.margins.bottom: placementBottom
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.keyboardInteractivity:
        LayerShell.Window.KeyboardInteractivityOnDemand
    LayerShell.Window.activateOnShow: true
    LayerShell.Window.wantsToBeOnActiveScreen: true

    DockEffects.BlurRegion {
        window: root
        region: Qt.rect(0, 0, root.width, root.height)
        radius: popupBackground.radius
        enabled: root.blurEnabled
    }

    function normalizedUrl(value) {
        return String(value || "").replace(/\/$/, "");
    }

    function folderName(value) {
        var path = decodeURIComponent(normalizedUrl(value));
        var slash = path.lastIndexOf("/");
        var name = slash >= 0 ? path.substring(slash + 1) : path;
        return name.length > 0 ? name : i18n("Folder");
    }

    function showPopup() {
        positionPopup();
        visible = true;
        requestActivate();
        Qt.callLater(positionPopup);
    }

    function positionPopup() {
        if (!visualParent) {
            return;
        }
        var owningWindow = visualParent.Window.window;
        if (!owningWindow || !owningWindow.contentItem) {
            return;
        }
        var targetScreen = owningWindow.screen || root.screen;
        if (!targetScreen) {
            return;
        }

        var localTopLeft = visualParent.mapToItem(
            owningWindow.contentItem, 0, 0);
        var screenLeft = targetScreen.virtualX;
        var screenTop = targetScreen.virtualY;
        var screenRight = screenLeft + targetScreen.width;
        var screenBottom = screenTop + targetScreen.height;
        var windowLeft;
        var windowTop;
        if (root.isVertical) {
            windowLeft = root.location === PlasmaCore.Types.LeftEdge
                ? screenLeft + root.screenEdgeMargin
                : screenRight - root.screenEdgeMargin - owningWindow.width;
            windowTop = screenTop
                + (targetScreen.height - owningWindow.height) / 2;
        } else {
            windowLeft = screenLeft
                + (targetScreen.width - owningWindow.width) / 2;
            windowTop = root.location === PlasmaCore.Types.TopEdge
                ? screenTop + root.screenEdgeMargin
                : screenBottom - root.screenEdgeMargin - owningWindow.height;
        }
        var itemTopLeft = Qt.point(windowLeft + localTopLeft.x,
            windowTop + localTopLeft.y);
        var spacing = Kirigami.Units.largeSpacing;

        placementLeft = 0;
        placementTop = 0;
        placementRight = 0;
        placementBottom = 0;

        if (root.isVertical) {
            placementTop = Math.max(spacing,
                Math.min(targetScreen.height - height - spacing,
                    itemTopLeft.y - screenTop
                        + (visualParent.height - height) / 2));
            if (root.location === PlasmaCore.Types.LeftEdge) {
                placementLeft = itemTopLeft.x - screenLeft
                    + visualParent.width + spacing;
            } else {
                placementRight = screenRight - itemTopLeft.x + spacing;
            }
        } else {
            placementLeft = Math.max(spacing,
                Math.min(targetScreen.width - width - spacing,
                    itemTopLeft.x - screenLeft
                        + (visualParent.width - width) / 2));
            if (root.location === PlasmaCore.Types.TopEdge) {
                placementTop = itemTopLeft.y - screenTop
                    + visualParent.height + spacing;
            } else {
                placementBottom = screenBottom - itemTopLeft.y + spacing;
            }
        }
    }

    onVisualParentChanged: {
        if (visible) {
            Qt.callLater(positionPopup);
        }
    }
    onWidthChanged: {
        if (visible) {
            Qt.callLater(positionPopup);
        }
    }
    onHeightChanged: {
        if (visible) {
            Qt.callLater(positionPopup);
        }
    }

    Shortcut {
        sequences: [StandardKey.Cancel]
        enabled: root.visible
        onActivated: root.close()
    }

    DockBackground {
        id: popupBackground

        anchors.fill: parent
        surfaceOpacity: root.surfaceOpacity
        useThemeColor: root.useThemeColor
        customColor: root.customColor
        requestedRadius: root.requestedRadius
        borderOpacity: root.borderOpacity
        shadowOpacity: root.shadowOpacity
        showHighlight: root.showHighlight
    }

    HoverHandler {
        id: popupHover
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            QQC2.ToolButton {
                visible: !root.atRootFolder
                icon.name: "go-previous"
                onClicked: root.folderModel.up()

                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: i18n("Back")
            }

            Kirigami.Icon {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                source: root.folderModel
                    ? (root.folderModel.iconName || "folder") : "folder"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                QQC2.Label {
                    Layout.fillWidth: true
                    text: root.currentFolderName
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    elide: Text.ElideMiddle
                }

                QQC2.Label {
                    text: i18n("Folder")
                    opacity: 0.68
                }
            }

            QQC2.ToolButton {
                icon.name: "document-open-folder"
                onClicked: root.openFolderRequested(
                    root.folderModel.resolvedUrl || root.rootFolderUrl)

                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: i18n("Open in File Manager")
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            radius: 11
            color: Kirigami.Theme.alternateBackgroundColor
            opacity: 0.86

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.smallSpacing
                anchors.rightMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                QQC2.ComboBox {
                    id: sortCombo

                    Layout.fillWidth: true
                    model: [i18n("Name"), i18n("Date"),
                        i18n("Size"), i18n("Type")]
                    onActivated: root.folderModel.sortMode
                        = [0, 2, 1, 6][currentIndex]
                }

                QQC2.ToolButton {
                    icon.name: root.folderModel && root.folderModel.sortDesc
                        ? "view-sort-descending" : "view-sort-ascending"
                    onClicked: root.folderModel.sortDesc
                        = !root.folderModel.sortDesc

                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: root.folderModel
                        && root.folderModel.sortDesc
                            ? i18n("Descending") : i18n("Ascending")
                }

                QQC2.ToolButton {
                    checkable: true
                    checked: root.folderModel
                        ? root.folderModel.showHiddenFiles : false
                    icon.name: checked ? "view-visible" : "view-hidden"
                    onToggled: root.folderModel.showHiddenFiles = checked

                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: checked
                        ? i18n("Hide hidden files")
                        : i18n("Show hidden files")
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: fileList

                anchors.fill: parent
                clip: true
                spacing: Kirigami.Units.smallSpacing
                model: root.folderModel
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: fileDelegate

                    required property int index
                    required property bool isDir
                    required property var size
                    required property string type
                    required property string display
                    required property var decoration

                    width: ListView.view.width
                    height: 64

                    Rectangle {
                        anchors.fill: parent
                        radius: 11
                        color: fileHover.hovered
                            ? Kirigami.Theme.highlightColor
                            : Kirigami.Theme.alternateBackgroundColor
                        opacity: fileHover.hovered ? 0.24 : 0.62

                        Behavior on opacity {
                            NumberAnimation { duration: 100 }
                        }
                    }

                    Kirigami.Icon {
                        anchors.left: parent.left
                        anchors.leftMargin: Kirigami.Units.largeSpacing
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        source: fileDelegate.decoration
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: Kirigami.Units.largeSpacing + 48
                        anchors.right: parent.right
                        anchors.rightMargin: Kirigami.Units.largeSpacing
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        QQC2.Label {
                            width: parent.width
                            text: fileDelegate.display
                            font.weight: Font.DemiBold
                            elide: Text.ElideMiddle
                        }

                        QQC2.Label {
                            width: parent.width
                            text: {
                                var itemSize = String(
                                    fileDelegate.size || "");
                                return itemSize.length > 0
                                        && itemSize !== "undefined"
                                    ? fileDelegate.type + " · " + itemSize
                                    : fileDelegate.type;
                            }
                            opacity: 0.66
                            elide: Text.ElideRight
                        }
                    }

                    HoverHandler {
                        id: fileHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: {
                            if (fileDelegate.isDir) {
                                root.folderModel.cd(fileDelegate.index);
                            } else {
                                root.folderModel.run(fileDelegate.index);
                                root.close();
                            }
                        }
                    }
                }

                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
            }

            QQC2.Label {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                visible: fileList.count === 0
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
                text: root.folderModel
                    && root.folderModel.errorString.length > 0
                        ? root.folderModel.errorString
                        : i18n("This folder is empty")
                opacity: 0.68
            }
        }
    }
}
