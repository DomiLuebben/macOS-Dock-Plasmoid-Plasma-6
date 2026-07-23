pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.layershell as LayerShell
import org.kde.plasma.core as PlasmaCore
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
    readonly property int listViewMode: 0
    readonly property int gridViewMode: 1
    readonly property int fanViewMode: 2
    property int viewMode: listViewMode

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
    property bool positionPending: false

    signal openFolderRequested(url folderUrl)
    signal viewModeRequested(int mode)

    width: root.viewMode === root.gridViewMode
        ? 420 : (root.viewMode === root.fanViewMode ? 380 : 356)
    height: screen
        ? Math.max(minimumHeight, Math.min(
            root.viewMode === root.fanViewMode ? 460 : 410,
            screen.height - 48)) : 410
    minimumWidth: 290
    minimumHeight: 280
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
        var path = normalizedUrl(value);
        try {
            path = decodeURIComponent(path);
        } catch (error) {
            // Keep malformed or partially escaped URLs readable
        }
        var slash = path.lastIndexOf("/");
        var name = slash >= 0 ? path.substring(slash + 1) : path;
        return name.length > 0 ? name : i18n("Folder");
    }

    function entryDetails(type, size) {
        var entryType = String(type || "");
        var entrySize = String(size || "");
        return entrySize.length > 0
            ? entryType + " · " + entrySize : entryType;
    }

    function activateEntry(index, isDirectory) {
        if (!folderModel) {
            return;
        }
        if (isDirectory) {
            folderModel.cd(index);
        } else {
            folderModel.run(index);
            close();
        }
    }

    function requestViewMode(mode) {
        if (mode >= listViewMode && mode <= fanViewMode
                && mode !== viewMode) {
            viewModeRequested(mode);
        }
    }

    function showPopup() {
        positionPopup();
        visible = true;
        requestActivate();
        schedulePositionPopup();
    }

    function schedulePositionPopup() {
        if (!visible || positionPending) {
            return;
        }
        positionPending = true;
        Qt.callLater(runScheduledPositionPopup);
    }

    function runScheduledPositionPopup() {
        positionPending = false;
        if (visible) {
            positionPopup();
        }
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

    onVisualParentChanged: if (visible) schedulePositionPopup()
    onWidthChanged: if (visible) schedulePositionPopup()
    onHeightChanged: if (visible) schedulePositionPopup()
    onScreenChanged: if (visible) schedulePositionPopup()
    onLocationChanged: if (visible) schedulePositionPopup()
    onScreenEdgeMarginChanged: if (visible) schedulePositionPopup()

    Connections {
        target: root.visualParent
        enabled: root.visible
        function onXChanged() { root.schedulePositionPopup(); }
        function onYChanged() { root.schedulePositionPopup(); }
        function onWidthChanged() { root.schedulePositionPopup(); }
        function onHeightChanged() { root.schedulePositionPopup(); }
    }

    Connections {
        target: root.visualParent ? root.visualParent.Window.window : null
        enabled: root.visible
        function onWidthChanged() { root.schedulePositionPopup(); }
        function onHeightChanged() { root.schedulePositionPopup(); }
        function onScreenChanged() { root.schedulePositionPopup(); }
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
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.ToolButton {
                visible: !root.atRootFolder
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                icon.name: "go-previous"
                onClicked: root.folderModel.up()

                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: i18n("Back")
            }

            Kirigami.Icon {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                source: root.folderModel
                    ? (root.folderModel.iconName || "folder") : "folder"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                QQC2.Label {
                    Layout.fillWidth: true
                    text: root.currentFolderName
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    elide: Text.ElideMiddle
                }
            }

            QQC2.ToolButton {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                icon.name: "document-open-folder"
                onClicked: root.openFolderRequested(
                    root.folderModel.resolvedUrl || root.rootFolderUrl)

                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: i18n("Open in File Manager")
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: 8
            color: Kirigami.Theme.alternateBackgroundColor

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Math.max(2, Kirigami.Units.smallSpacing / 2)
                anchors.rightMargin: Math.max(2, Kirigami.Units.smallSpacing / 2)
                spacing: Kirigami.Units.smallSpacing

                Rectangle {
                    Layout.preferredWidth: 108
                    Layout.preferredHeight: 28
                    radius: 6
                    color: Kirigami.Theme.backgroundColor
                    border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                        Kirigami.Theme.textColor.g,
                        Kirigami.Theme.textColor.b, 0.16)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        QQC2.ToolButton {
                            id: listViewButton

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: i18n("List View")
                            display: QQC2.AbstractButton.IconOnly
                            icon.name: "view-list-details"
                            checked: root.viewMode === root.listViewMode
                            onClicked: root.requestViewMode(root.listViewMode)

                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.text: listViewButton.text
                        }

                        QQC2.ToolButton {
                            id: gridViewButton

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: i18n("Grid View")
                            display: QQC2.AbstractButton.IconOnly
                            icon.name: "view-grid"
                            checked: root.viewMode === root.gridViewMode
                            onClicked: root.requestViewMode(root.gridViewMode)

                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.text: gridViewButton.text
                        }

                        QQC2.ToolButton {
                            id: fanViewButton

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: i18n("Fan / Stack View")
                            display: QQC2.AbstractButton.IconOnly
                            icon.name: "view-list-icons"
                            checked: root.viewMode === root.fanViewMode
                            onClicked: root.requestViewMode(root.fanViewMode)

                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.text: fanViewButton.text
                        }
                    }
                }

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
                visible: root.viewMode === root.listViewMode
                clip: true
                spacing: Math.max(2, Kirigami.Units.smallSpacing / 2)
                model: root.visible && fileList.visible
                    ? root.folderModel : null
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true
                cacheBuffer: 104

                delegate: Item {
                    id: fileDelegate
                    required property int index
                    required property bool isDir
                    required property var size
                    required property string type
                    required property string display
                    required property var decoration

                    width: ListView.view.width
                    height: 48

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
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
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        source: fileDelegate.decoration
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: Kirigami.Units.smallSpacing + 36
                        anchors.right: parent.right
                        anchors.rightMargin: Kirigami.Units.smallSpacing
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
                            text: root.entryDetails(fileDelegate.type,
                                fileDelegate.size)
                            opacity: 0.66
                            elide: Text.ElideRight
                        }
                    }

                    HoverHandler {
                        id: fileHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: root.activateEntry(fileDelegate.index,
                            fileDelegate.isDir)
                    }
                }

                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
            }

            GridView {
                id: fileGrid
                anchors.fill: parent
                visible: root.viewMode === root.gridViewMode
                clip: true
                cellWidth: 98
                cellHeight: 96
                model: root.visible && fileGrid.visible
                    ? root.folderModel : null
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true
                cacheBuffer: 104

                delegate: Item {
                    id: gridDelegate
                    required property int index
                    required property bool isDir
                    required property string display
                    required property var decoration

                    width: GridView.view.cellWidth
                    height: GridView.view.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 10
                        color: gridHover.hovered
                            ? Kirigami.Theme.highlightColor
                            : Kirigami.Theme.alternateBackgroundColor
                        opacity: gridHover.hovered ? 0.28 : 0.45

                        Behavior on opacity {
                            NumberAnimation { duration: 100 }
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 2

                        Kirigami.Icon {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 44
                            source: gridDelegate.decoration
                        }

                        QQC2.Label {
                            Layout.fillWidth: true
                            text: gridDelegate.display
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                            maximumLineCount: 2
                            wrapMode: Text.WrapAnywhere
                            elide: Text.ElideRight
                        }
                    }

                    HoverHandler {
                        id: gridHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: root.activateEntry(gridDelegate.index,
                            gridDelegate.isDir)
                    }
                }

                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
            }

            ListView {
                id: fileFanList
                anchors.fill: parent
                visible: root.viewMode === root.fanViewMode
                clip: true
                spacing: 6
                model: root.visible && fileFanList.visible
                    ? root.folderModel : null
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true
                cacheBuffer: 104

                delegate: Item {
                    id: fanDelegate
                    required property int index
                    required property bool isDir
                    required property var size
                    required property string type
                    required property string display
                    required property var decoration

                    width: ListView.view.width
                    height: 44

                    readonly property real arcOffset: Math.sin(
                        Math.min(1.0, fanDelegate.index / Math.max(1,
                            fileFanList.count - 1)) * Math.PI * 0.7
                    ) * 28

                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: Math.max(4, fanDelegate.arcOffset)
                        anchors.rightMargin: Math.max(4, 28 - fanDelegate.arcOffset)

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: fanHover.hovered
                                ? Kirigami.Theme.highlightColor
                                : Kirigami.Theme.alternateBackgroundColor
                            opacity: fanHover.hovered ? 0.32 : 0.68
                            border.color: fanHover.hovered
                                ? Kirigami.Theme.highlightColor
                                : Qt.rgba(255, 255, 255, 0.1)
                            border.width: 1

                            scale: fanHover.hovered ? 1.02 : 1.0
                            Behavior on scale {
                                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                            }
                            Behavior on opacity {
                                NumberAnimation { duration: 100 }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Kirigami.Units.smallSpacing + 2
                            anchors.rightMargin: Kirigami.Units.smallSpacing + 2
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                source: fanDelegate.decoration
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: fanDelegate.display
                                    font.weight: Font.Bold
                                    font.pixelSize: 12
                                    elide: Text.ElideMiddle
                                }

                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: root.entryDetails(fanDelegate.type,
                                        fanDelegate.size)
                                    font.pixelSize: 10
                                    opacity: 0.7
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        HoverHandler {
                            id: fanHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: root.activateEntry(fanDelegate.index,
                                fanDelegate.isDir)
                        }
                    }
                }

                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
            }

            QQC2.Label {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                visible: (root.viewMode === root.listViewMode
                        && fileList.count === 0)
                    || (root.viewMode === root.gridViewMode
                        && fileGrid.count === 0)
                    || (root.viewMode === root.fanViewMode
                        && fileFanList.count === 0)
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
