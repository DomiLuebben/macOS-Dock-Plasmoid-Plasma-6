pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

Item {
    id: root

    property var windowsList: []
    property var appIcon: "application-x-executable"
    property string appName: ""
    property bool captureRequested: false
    property bool captureActive: false

    readonly property int previewCount: windowsList
        ? windowsList.length : 0
    readonly property int previewColumns:
        Math.min(Math.max(1, previewCount), 3)
    readonly property int previewRows:
        Math.max(1, Math.ceil(previewCount / previewColumns))
    readonly property real previewGridWidth: previewColumns * 192
        + (previewColumns - 1) * Kirigami.Units.smallSpacing
    readonly property real previewGridHeight: previewRows * 136
        + (previewRows - 1) * Kirigami.Units.smallSpacing
    readonly property real maximumPreviewWidth:
        Math.max(192, Screen.desktopAvailableWidth
            - Kirigami.Units.gridUnit * 2)
    readonly property real maximumPreviewHeight:
        Math.max(136, Screen.desktopAvailableHeight * 0.7)
    readonly property real previewViewportWidth:
        Math.min(previewGridWidth, maximumPreviewWidth)
    readonly property real previewViewportHeight:
        Math.min(previewGridHeight, maximumPreviewHeight)

    signal windowActivated(var modelIndex)
    signal windowClosed(var modelIndex)

    implicitWidth: Math.max(previewViewportWidth,
        appTitle.visible
            ? Math.min(appTitle.implicitWidth, maximumPreviewWidth) : 0)
    implicitHeight: previewViewportHeight + (appTitle.visible
        ? appTitle.implicitHeight + contentLayout.spacing : 0)

    Kirigami.Theme.colorSet: Kirigami.Theme.Tooltip
    Kirigami.Theme.inherit: false

    onCaptureRequestedChanged: {
        if (captureRequested) {
            captureStartTimer.restart();
        } else {
            captureStartTimer.stop();
            captureActive = false;
        }
    }

    Timer {
        id: captureStartTimer

        interval: 100
        repeat: false
        onTriggered: root.captureActive = true
    }

    ColumnLayout {
        id: contentLayout

        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            id: appTitle

            text: root.appName
            font.bold: true
            visible: root.appName.length > 0
            elide: Text.ElideRight
            Layout.maximumWidth: root.maximumPreviewWidth
            Layout.alignment: Qt.AlignHCenter
        }

        QQC2.ScrollView {
            id: previewScrollView

            Layout.preferredWidth: root.previewViewportWidth
            Layout.preferredHeight: root.previewViewportHeight
            contentWidth: previewGrid.implicitWidth
            contentHeight: previewGrid.implicitHeight
            clip: true

            GridLayout {
                id: previewGrid

                columns: root.previewColumns
                rowSpacing: Kirigami.Units.smallSpacing
                columnSpacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: root.windowsList

                    delegate: Item {
                        id: previewCard

                        required property var modelData
                        required property int index
                        property bool previewTimedOut: false

                        width: 192
                        height: 136

                        Rectangle {
                            anchors.fill: parent
                            radius: Kirigami.Units.cornerRadius
                            color: cardMouseArea.containsMouse
                                ? Qt.rgba(Kirigami.Theme.textColor.r,
                                    Kirigami.Theme.textColor.g,
                                    Kirigami.Theme.textColor.b, 0.16)
                                : Qt.rgba(Kirigami.Theme.textColor.r,
                                    Kirigami.Theme.textColor.g,
                                    Kirigami.Theme.textColor.b, 0.07)
                            border.color: previewCard.modelData.isActive
                                ? Kirigami.Theme.highlightColor
                                : Qt.rgba(Kirigami.Theme.textColor.r,
                                    Kirigami.Theme.textColor.g,
                                    Kirigami.Theme.textColor.b, 0.18)
                            border.width: previewCard.modelData.isActive ? 2 : 1

                            Behavior on color {
                                ColorAnimation {
                                    duration: Kirigami.Units.shortDuration
                                }
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.smallSpacing
                            spacing: Kirigami.Units.smallSpacing

                            Item {
                                id: thumbnailContainer

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true

                                PipeWireThumbnail {
                                    id: pipeWireThumbnail

                                    readonly property var requestedWindowId:
                                        previewCard.modelData.winId
                                    readonly property bool requestActive:
                                        root.captureActive
                                        && requestedWindowId !== undefined
                                        && requestedWindowId !== null
                                        && String(requestedWindowId).length > 0

                                    anchors.fill: parent
                                    windowId: requestActive
                                        ? requestedWindowId : ""
                                    visible: requestActive

                                    onWindowIdChanged:
                                        previewCard.previewTimedOut = false
                                }

                                Timer {
                                    interval: 2500
                                    running: pipeWireThumbnail.requestActive
                                        && !pipeWireThumbnail.hasThumbnail
                                    onTriggered:
                                        previewCard.previewTimedOut = true
                                }

                                PlasmaCore.WindowThumbnail {
                                    id: legacyThumbnail

                                    anchors.fill: parent
                                    winId: {
                                        var id = Number(previewCard.modelData.winId);
                                        return Number.isFinite(id) && id > 0 ? id : 0;
                                    }
                                    visible: !pipeWireThumbnail.hasThumbnail
                                        && legacyThumbnail.thumbnailAvailable
                                        && legacyThumbnail.winId > 0
                                }

                                QQC2.BusyIndicator {
                                    anchors.centerIn: parent
                                    width: Kirigami.Units.iconSizes.medium
                                    height: width
                                    running: visible
                                    visible: pipeWireThumbnail.requestActive
                                        && !previewCard.previewTimedOut
                                        && !pipeWireThumbnail.hasThumbnail
                                        && !legacyThumbnail.visible
                                }

                                QQC2.Label {
                                    anchors.centerIn: parent
                                    width: parent.width
                                        - Kirigami.Units.gridUnit
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.Wrap
                                    opacity: 0.7
                                    // Provided by the Plasma applet translation
                                    // context.
                                    // qmllint disable unqualified
                                    text: i18n("Preview unavailable")
                                    // qmllint enable unqualified
                                    visible: !pipeWireThumbnail.hasThumbnail
                                        && !legacyThumbnail.visible
                                        && (!pipeWireThumbnail.requestActive
                                            || previewCard.previewTimedOut)
                                }
                            }

                            QQC2.Label {
                                text: String(previewCard.modelData.title
                                    || root.appName)
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                opacity: 0.8
                            }
                        }

                        MouseArea {
                            id: cardMouseArea

                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            activeFocusOnTab: true

                            Accessible.role: Accessible.Button
                            Accessible.name: String(previewCard.modelData.title
                                || root.appName)
                            Accessible.onPressAction: activateWindow()

                            Keys.onReturnPressed: activateWindow()
                            Keys.onEnterPressed: activateWindow()
                            Keys.onSpacePressed: activateWindow()
                            Keys.onDeletePressed: closeWindow()

                            onClicked: (mouse) => {
                                if (mouse.button === Qt.MiddleButton) {
                                    closeWindow();
                                } else {
                                    activateWindow();
                                }
                            }

                            function activateWindow() {
                                root.windowActivated(
                                    previewCard.modelData.modelIndex);
                            }

                            function closeWindow() {
                                root.windowClosed(
                                    previewCard.modelData.modelIndex);
                            }
                        }

                        QQC2.ToolButton {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: Kirigami.Units.smallSpacing
                            width: Kirigami.Units.iconSizes.smallMedium
                            height: width
                            z: 2
                            visible: cardMouseArea.containsMouse || activeFocus
                            focusPolicy: Qt.TabFocus
                            icon.name: "window-close"
                            display: QQC2.AbstractButton.IconOnly
                            // Provided by the Plasma applet translation context.
                            // qmllint disable unqualified
                            text: i18n("Close")
                            // qmllint enable unqualified
                            onClicked: cardMouseArea.closeWindow()
                        }
                    }
                }
            }
        }
    }
}
