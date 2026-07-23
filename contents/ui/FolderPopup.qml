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
    property int viewMode: 0 // 0: List, 1: Grid, 2: Fan / Stack

    onViewModeChanged: {
        if (viewMode < 0 || viewMode > 2) {
            viewMode = 0;
        }
    }

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

    width: root.viewMode === 1 ? 420 : (root.viewMode === 2 ? 380 : 356)
    height: screen
        ? Math.max(minimumHeight, Math.min(root.viewMode === 2 ? 460 : 410, screen.height - 48)) : 410
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

        // Top Navigation & Title Bar
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

        // View Mode & Sorting Control Bar (macOS Tahoe style)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: 8
            color: Kirigami.Theme.alternateBackgroundColor
            opacity: 0.86

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Math.max(2, Kirigami.Units.smallSpacing / 2)
                anchors.rightMargin: Math.max(2, Kirigami.Units.smallSpacing / 2)
                spacing: Kirigami.Units.smallSpacing

                // View Mode Segmented Switcher (List / Grid / Fan)
                Rectangle {
                    Layout.preferredWidth: 108
                    Layout.preferredHeight: 28
                    radius: 6
                    color: Qt.rgba(0, 0, 0, 0.18)
                    border.color: Qt.rgba(255, 255, 255, 0.12)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        QQC2.ToolButton {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            icon.name: "view-list-details"
                            checkable: true
                            checked: root.viewMode === 0
                            onClicked: root.viewMode = 0

                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.text: i18n("List View")
                        }

                        QQC2.ToolButton {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            icon.name: "view-grid"
                            checkable: true
                            checked: root.viewMode === 1
                            onClicked: root.viewMode = 1

                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.text: i18n("Grid View")
                        }

                        QQC2.ToolButton {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            icon.name: "view-pages"
                            checkable: true
                            checked: root.viewMode === 2
                            onClicked: root.viewMode = 2

                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.text: i18n("Fan / Stack View")
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

        // Main Content Area (List / Grid / Fan View)
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // MODE 0: LISTENANSICHT (LIST VIEW)
            ListView {
                id: fileList
                anchors.fill: parent
                visible: root.viewMode === 0
                clip: true
                spacing: Math.max(2, Kirigami.Units.smallSpacing / 2)
                model: root.folderModel
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
                            text: {
                                var itemSize = String(fileDelegate.size || "");
                                return itemSize.length > 0 && itemSize !== "undefined"
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

            // MODE 1: GRIDANSICHT (GRID VIEW)
            GridView {
                id: fileGrid
                anchors.fill: parent
                visible: root.viewMode === 1
                clip: true
                cellWidth: 98
                cellHeight: 96
                model: root.folderModel
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true
                cacheBuffer: 104

                delegate: Item {
                    id: gridDelegate
                    required property int index
                    required property bool isDir
                    required property var size
                    required property string type
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
                        onTapped: {
                            if (gridDelegate.isDir) {
                                root.folderModel.cd(gridDelegate.index);
                            } else {
                                root.folderModel.run(gridDelegate.index);
                                root.close();
                            }
                        }
                    }
                }

                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
            }

            // MODE 2: STAPELANSICHT / FAN VIEW (macOS FAN VIEW)
            ListView {
                id: fileFanList
                anchors.fill: parent
                visible: root.viewMode === 2
                clip: true
                spacing: 6
                model: root.folderModel
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

                    // macOS Fan Arc Curved Layout Shift
                    readonly property real arcOffset: Math.sin(
                        Math.min(1.0, fanDelegate.index / Math.max(1, (fileFanList.count || 1) - 1)) * Math.PI * 0.7
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
                                    text: {
                                        var itemSize = String(fanDelegate.size || "");
                                        return itemSize.length > 0 && itemSize !== "undefined"
                                            ? fanDelegate.type + " · " + itemSize
                                            : fanDelegate.type;
                                    }
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
                            onTapped: {
                                if (fanDelegate.isDir) {
                                    root.folderModel.cd(fanDelegate.index);
                                } else {
                                    root.folderModel.run(fanDelegate.index);
                                    root.close();
                                }
                            }
                        }
                    }
                }

                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
            }

            // Empty Folder Label
            QQC2.Label {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                visible: (root.viewMode === 0 && fileList.count === 0)
                      || (root.viewMode === 1 && fileGrid.count === 0)
                      || (root.viewMode === 2 && fileFanList.count === 0)
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
