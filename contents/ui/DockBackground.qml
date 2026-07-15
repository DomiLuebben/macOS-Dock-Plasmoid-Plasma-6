pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami

Kirigami.ShadowedRectangle {
    id: background

    property real surfaceOpacity: 0.55

    readonly property color themeBackground: qtPalette.window
    readonly property color themeText: qtPalette.windowText

    SystemPalette {
        id: qtPalette

        colorGroup: SystemPalette.Active
    }

    radius: Math.min(Kirigami.Units.cornerRadius * 2,
        Math.min(width, height) / 2)
    color: Qt.rgba(themeBackground.r, themeBackground.g,
        themeBackground.b, surfaceOpacity)

    border.width: 1
    border.color: Qt.rgba(themeText.r, themeText.g, themeText.b, 0.22)

    shadow.xOffset: 0
    shadow.yOffset: 2
    shadow.size: 10
    shadow.color: Qt.rgba(0, 0, 0, 0.42)

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, background.radius - 1)
        color: "transparent"

        gradient: Gradient {
            orientation: Gradient.Vertical

            GradientStop {
                position: 0
                color: Qt.rgba(1, 1, 1, 0.14)
            }

            GradientStop {
                position: 0.55
                color: Qt.rgba(1, 1, 1, 0.025)
            }

            GradientStop {
                position: 1
                color: Qt.rgba(0, 0, 0, 0.08)
            }
        }
    }
}
