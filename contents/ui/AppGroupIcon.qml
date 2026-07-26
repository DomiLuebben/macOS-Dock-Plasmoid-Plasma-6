pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root

    property var previewItems: []

    readonly property int previewCount:
        Math.min(4, previewItems ? previewItems.length : 0)
    readonly property real outerPadding: width * 0.105
    readonly property real cellGap: width * 0.045
    readonly property real cellSize:
        (width - 2 * outerPadding - cellGap) / 2

    Rectangle {
        anchors.fill: parent
        radius: Math.max(8, width * 0.22)
        color: Qt.rgba(Kirigami.Theme.backgroundColor.r,
            Kirigami.Theme.backgroundColor.g,
            Kirigami.Theme.backgroundColor.b, 0.88)
        border.width: Math.max(1, width / 48)
        border.color: Qt.rgba(Kirigami.Theme.textColor.r,
            Kirigami.Theme.textColor.g,
            Kirigami.Theme.textColor.b, 0.22)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(7, parent.radius - 1)
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.16)
        }
    }

    Repeater {
        model: root.previewCount

        delegate: Item {
            id: previewDelegate

            required property int index
            readonly property var preview:
                root.previewItems[index] || ({})
            readonly property int column: index % 2
            readonly property int row: Math.floor(index / 2)

            x: root.outerPadding
                + column * (root.cellSize + root.cellGap)
            y: root.outerPadding
                + row * (root.cellSize + root.cellGap)
            width: root.cellSize
            height: root.cellSize

            Kirigami.Icon {
                anchors.fill: parent
                source: previewDelegate.preview.icon
                    || "application-x-executable"
                roundToIconSize: false
                smooth: true
            }
        }
    }

    // The folder is born from the two source icons instead of abruptly
    // replacing them. The restrained overshoot mirrors Android's accept/drop
    // feedback without disturbing the Dock's own magnification wave.
    scale: 0.72
    opacity: 0

    SequentialAnimation {
        id: formationAnimation

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "opacity"
                from: 0
                to: 1
                duration: 120
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "scale"
                from: 0.72
                to: 1.035
                duration: 190
                easing.type: Easing.OutCubic
            }
        }
        NumberAnimation {
            target: root
            property: "scale"
            to: 1
            duration: 90
            easing.type: Easing.InOutCubic
        }
    }

    Component.onCompleted: formationAnimation.start()
}
