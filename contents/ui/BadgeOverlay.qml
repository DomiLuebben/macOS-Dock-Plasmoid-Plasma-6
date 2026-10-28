pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import "BadgeStore.js" as BadgeStore

// Unread badge on the corner of a dock icon, or of a group folder. It sits on
// the icon itself and reaches a little past its edge, so it stays visible
// while the folder is closed.
//
// This root is only the frame the Loader resizes to the icon; the badge is the
// inner item, so its own size is never overwritten by the Loader.
Item {
    id: root

    property int count: 0
    // The KDE Connect share badge owns the top-right corner; step aside.
    property bool onLeft: false

    readonly property string label: BadgeStore.badgeLabel(root.count)

    Item {
        id: badge

        // For tests and accessibility tooling.
        objectName: "unreadBadge"
        readonly property string label: root.label
        readonly property bool onLeft: root.onLeft

        visible: label.length > 0
        height: Math.max(16, Math.round(root.width * 0.34))
        width: Math.max(height, Math.round(textMetrics.width + height * 0.62))
        x: root.onLeft
            ? -Math.round(height * 0.2)
            : root.width - width + Math.round(height * 0.2)
        y: -Math.round(height * 0.18)
        z: 90

        Accessible.role: Accessible.StaticText
        Accessible.name: i18np("%1 unread message", "%1 unread messages", root.count)

        TextMetrics {
            id: textMetrics
            font: labelText.font
            text: root.label
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: "#ff3b30"
            border.color: Qt.rgba(1, 1, 1, 0.9)
            border.width: Math.max(1, Math.round(badge.height / 14))

            // Appears with a small overshoot, like a native macOS badge.
            scale: badge.visible ? 1 : 0.5
            Behavior on scale {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutBack
                }
            }
        }

        Text {
            id: labelText

            anchors.centerIn: parent
            text: root.label
            color: "white"
            font.bold: true
            font.pixelSize: Math.round(badge.height * 0.58)
            renderType: Text.NativeRendering
        }
    }
}
