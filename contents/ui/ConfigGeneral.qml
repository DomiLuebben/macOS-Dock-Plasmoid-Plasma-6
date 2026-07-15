pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: configPage

    property alias cfg_maxScale: maxScaleSlider.value
    property alias cfg_zoomRadius: zoomRadiusSlider.value
    property alias cfg_iconSize: iconSizeSlider.value
    property alias cfg_dockMargin: dockMarginSlider.value
    property alias cfg_dockCrossMargin: dockCrossMarginSlider.value
    property alias cfg_screenEdgeMargin: screenEdgeMarginSlider.value
    property alias cfg_backgroundOpacity: backgroundOpacitySlider.value
    property alias cfg_hideOnMaximized: hideOnMaximizedCheckBox.checked
    property alias cfg_launchAnimation: launchAnimationCombo.currentIndex
    property var cfg_launchers: []

    // Plasma passes default values to configuration pages as initial
    // properties. Keeping them explicit also makes reset-to-default reliable.
    property real cfg_maxScaleDefault: 1.45
    property int cfg_zoomRadiusDefault: 70
    property int cfg_iconSizeDefault: 44
    property int cfg_dockMarginDefault: 16
    property int cfg_dockCrossMarginDefault: 5
    property int cfg_screenEdgeMarginDefault: 8
    property real cfg_backgroundOpacityDefault: 0.55
    property bool cfg_hideOnMaximizedDefault: true
    property int cfg_launchAnimationDefault: 1
    property var cfg_launchersDefault: []

    // Accepted for compatibility with the configuration page instance that
    // existed before 1.3 and with Plasma's standard applet page properties.
    property bool cfg_showDockBackground: false
    property bool cfg_showDockBackgroundDefault: false
    property bool cfg_expanding: false
    property int cfg_length: 0

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Appearance")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Icon size:")

            QQC2.Slider {
                id: iconSizeSlider
                Layout.fillWidth: true
                from: 24
                to: 96
                stepSize: 2
                live: true
            }

            QQC2.Label {
                text: Math.round(iconSizeSlider.value) + i18n(" px")
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Left/right margin:")

            QQC2.Slider {
                id: dockMarginSlider
                Layout.fillWidth: true
                from: 4
                to: 40
                stepSize: 1
                live: true
            }

            QQC2.Label {
                text: Math.round(dockMarginSlider.value) + i18n(" px")
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Top/bottom margin:")

            QQC2.Slider {
                id: dockCrossMarginSlider
                Layout.fillWidth: true
                from: 0
                to: 20
                stepSize: 1
                live: true
            }

            QQC2.Label {
                text: Math.round(dockCrossMarginSlider.value) + i18n(" px")
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Distance from screen edge:")

            QQC2.Slider {
                id: screenEdgeMarginSlider
                Layout.fillWidth: true
                from: 0
                to: 32
                stepSize: 1
                live: true
            }

            QQC2.Label {
                text: Math.round(screenEdgeMarginSlider.value) + i18n(" px")
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Background opacity:")

            QQC2.Slider {
                id: backgroundOpacitySlider
                Layout.fillWidth: true
                from: 0.15
                to: 0.9
                stepSize: 0.05
                live: true
            }

            QQC2.Label {
                text: Math.round(backgroundOpacitySlider.value * 100) + "%"
            }
        }

        QQC2.CheckBox {
            id: hideOnMaximizedCheckBox

            Kirigami.FormData.label: i18n("Window behavior:")
            text: i18n("Automatically hide when a window is maximized")
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Magnification and animation")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Maximum magnification:")

            QQC2.Slider {
                id: maxScaleSlider
                Layout.fillWidth: true
                from: 1.0
                to: 2.0
                stepSize: 0.05
                live: true
            }

            QQC2.Label {
                text: maxScaleSlider.value.toFixed(2) + "×"
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Magnification radius:")

            QQC2.Slider {
                id: zoomRadiusSlider
                Layout.fillWidth: true
                from: 30
                to: 200
                stepSize: 5
                live: true
            }

            QQC2.Label {
                text: Math.round(zoomRadiusSlider.value) + i18n(" px")
            }
        }

        QQC2.ComboBox {
            id: launchAnimationCombo

            Kirigami.FormData.label: i18n("Launch animation:")
            Layout.fillWidth: true
            model: [i18n("None"), i18n("Bounce")]
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Applications")
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Dock content:")
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: i18n("Running applications appear automatically. Right-click an icon to keep it in the Dock, unpin it, or move it. The widget does not include fixed launchers.")
            opacity: 0.78
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Panel integration:")
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: i18n("The Dock runs in its own transparent window at the screen edge. BetterBlur can blur this window directly. The invisible desktop widget only persists settings and launchers.")
            opacity: 0.78
        }
    }
}
