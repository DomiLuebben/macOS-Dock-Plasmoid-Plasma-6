pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import QtCore
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls

KCM.SimpleKCM {
    id: configPage

    property alias cfg_dockPosition: dockPositionCombo.currentIndex
    property alias cfg_maxScale: maxScaleSlider.value
    property alias cfg_zoomRadius: zoomRadiusSlider.value
    property alias cfg_iconSize: iconSizeSlider.value
    property alias cfg_dockMargin: dockMarginSlider.value
    property alias cfg_dockCrossMargin: dockCrossMarginSlider.value
    property alias cfg_screenEdgeMargin: screenEdgeMarginSlider.value
    property alias cfg_backgroundOpacity: backgroundOpacitySlider.value
    property alias cfg_useThemeBackground: useThemeBackgroundCheckBox.checked
    property alias cfg_customBackgroundColor: backgroundColorButton.color
    property alias cfg_cornerRadius: cornerRadiusSlider.value
    property alias cfg_borderOpacity: borderOpacitySlider.value
    property alias cfg_shadowOpacity: shadowOpacitySlider.value
    property alias cfg_showHighlight: showHighlightCheckBox.checked
    property alias cfg_enableBlur: enableBlurCheckBox.checked
    property alias cfg_hideOnMaximized: hideOnMaximizedCheckBox.checked
    property alias cfg_launchAnimation: launchAnimationCombo.currentIndex
    property alias cfg_showFolderView: showFolderViewCheckBox.checked
    property alias cfg_folderViewMode: folderViewModeCombo.currentIndex
    property alias cfg_appGroupViewMode: appGroupViewModeCombo.currentIndex
    property alias cfg_folderUrl: folderUrlField.text
    property var cfg_folderUrls: []
    property alias cfg_showTrash: showTrashCheckBox.checked
    property alias cfg_showRemovableVolumes: showRemovableVolumesCheckBox.checked
    property alias cfg_showDesktopSwitcher:
        showDesktopSwitcherCheckBox.checked
    property alias cfg_desktopSwitcherPosition:
        desktopSwitcherPositionCombo.currentIndex
    property alias cfg_desktopSwitcherLabelMode:
        desktopSwitcherLabelModeCombo.currentIndex
    property alias cfg_showPowerButton:
        showPowerButtonCheckBox.checked
    property alias cfg_powerButtonPosition:
        powerButtonPositionCombo.currentIndex
    property alias cfg_showProgressIndicators:
        showProgressIndicatorsCheckBox.checked
    property alias cfg_showKdeConnectRecentShares:
        showKdeConnectRecentSharesCheckBox.checked
    property var cfg_launchers: []
    property var cfg_appGroups: []

    // Accepted for compatibility with the configuration page instance that
    // existed before 1.3 and with Plasma's standard applet page properties.
    property bool cfg_showDockBackground: false
    property bool cfg_expanding: false
    property int cfg_length: 0

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Appearance")
        }

        QQC2.ComboBox {
            id: dockPositionCombo

            Kirigami.FormData.label: i18n("Dock position:")
            model: [i18n("Bottom"), i18n("Left"), i18n("Right")]
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
                to: 1.0
                stepSize: 0.05
                live: true
            }

            QQC2.Label {
                text: Math.round(backgroundOpacitySlider.value * 100) + "%"
            }
        }

        QQC2.CheckBox {
            id: useThemeBackgroundCheckBox

            Kirigami.FormData.label: i18n("Background:")
            text: i18n("Use color from the Plasma theme")
        }

        KQuickControls.ColorButton {
            id: backgroundColorButton

            Kirigami.FormData.label: i18n("Custom background color:")
            enabled: !useThemeBackgroundCheckBox.checked
            showAlphaChannel: false
            dialogTitle: i18n("Choose Dock Background Color")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Corner radius:")

            QQC2.Slider {
                id: cornerRadiusSlider
                Layout.fillWidth: true
                from: 0
                to: 48
                stepSize: 1
                live: true
            }

            QQC2.Label {
                text: Math.round(cornerRadiusSlider.value) + i18n(" px")
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Border strength:")

            QQC2.Slider {
                id: borderOpacitySlider
                Layout.fillWidth: true
                from: 0
                to: 0.5
                stepSize: 0.02
                live: true
            }

            QQC2.Label {
                text: Math.round(borderOpacitySlider.value * 100) + "%"
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Shadow strength:")

            QQC2.Slider {
                id: shadowOpacitySlider
                Layout.fillWidth: true
                from: 0
                to: 0.7
                stepSize: 0.02
                live: true
            }

            QQC2.Label {
                text: Math.round(shadowOpacitySlider.value * 100) + "%"
            }
        }

        ColumnLayout {
            Kirigami.FormData.label: i18n("Effects:")

            QQC2.CheckBox {
                id: enableBlurCheckBox
                text: i18n("Blur the background")
            }

            QQC2.CheckBox {
                id: showHighlightCheckBox
                text: i18n("Show glass highlight")
            }
        }

        Item {
            Kirigami.FormData.label: i18n("Preview:")
            Layout.fillWidth: true
            implicitHeight: 64

            DockBackground {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(parent.width, 280)
                height: 52
                surfaceOpacity: backgroundOpacitySlider.value
                useThemeColor: useThemeBackgroundCheckBox.checked
                customColor: backgroundColorButton.color
                requestedRadius: cornerRadiusSlider.value
                borderOpacity: borderOpacitySlider.value
                shadowOpacity: shadowOpacitySlider.value
                showHighlight: showHighlightCheckBox.checked
            }
        }

        QQC2.CheckBox {
            id: hideOnMaximizedCheckBox

            Kirigami.FormData.label: i18n("Window behavior:")
            text: i18n("Automatically hide when a window is maximized")
        }

        QQC2.CheckBox {
            id: showProgressIndicatorsCheckBox

            Kirigami.FormData.label: i18n("Integrations:")
            text: i18n("Show download and job progress indicators")
        }

        QQC2.CheckBox {
            id: showKdeConnectRecentSharesCheckBox

            text: i18n("Show KDE Connect recent shares")
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
            Kirigami.FormData.label: i18n("Dock items")
        }

        ColumnLayout {
            Kirigami.FormData.label: i18n("Utilities:")

            QQC2.CheckBox {
                id: showFolderViewCheckBox
                text: i18n("Show folder view")
            }

            QQC2.CheckBox {
                id: showTrashCheckBox
                text: i18n("Show Trash")
            }

            QQC2.CheckBox {
                id: showRemovableVolumesCheckBox
                text: i18n("Show removable drives")
            }

            QQC2.CheckBox {
                id: showDesktopSwitcherCheckBox
                text: i18n("Show desktop switcher")
            }

            QQC2.CheckBox {
                id: showPowerButtonCheckBox
                text: i18n("Show power button")
            }
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("View layouts")
        }

        QQC2.ComboBox {
            id: appGroupViewModeCombo

            Kirigami.FormData.label: i18n("App group layout:")
            Layout.fillWidth: true
            model: [i18n("List View"), i18n("Grid View")]
        }

        QQC2.ComboBox {
            id: folderViewModeCombo

            Kirigami.FormData.label: i18n("Folder view mode:")
            Layout.fillWidth: true
            enabled: showFolderViewCheckBox.checked
            model: [i18n("List View"), i18n("Grid View"), i18n("Fan / Stack View")]
        }

        QQC2.ComboBox {
            id: powerButtonPositionCombo

            Kirigami.FormData.label: i18n("Power button position:")
            Layout.fillWidth: true
            enabled: showPowerButtonCheckBox.checked
            model: [i18n("Left"), i18n("Right")]
        }

        QQC2.ComboBox {
            id: desktopSwitcherPositionCombo

            Kirigami.FormData.label: i18n("Desktop switcher position:")
            Layout.fillWidth: true
            enabled: showDesktopSwitcherCheckBox.checked
            model: [i18n("Left"), i18n("Right")]
        }

        QQC2.ComboBox {
            id: desktopSwitcherLabelModeCombo

            Kirigami.FormData.label: i18n("Desktop labels:")
            Layout.fillWidth: true
            enabled: showDesktopSwitcherCheckBox.checked
            model: [i18n("Numbers"), i18n("Desktop names")]
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Desktop names:")
            Layout.fillWidth: true
            visible: showDesktopSwitcherCheckBox.checked
                && desktopSwitcherLabelModeCombo.currentIndex === 1
            wrapMode: Text.WordWrap
            text: i18n("The names configured in Plasma, including custom names, are shown.")
            opacity: 0.78
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Default folder:")
            Layout.fillWidth: true
            enabled: showFolderViewCheckBox.checked

            QQC2.TextField {
                id: folderUrlField

                Layout.fillWidth: true
                placeholderText: StandardPaths.writableLocation(
                    StandardPaths.DownloadLocation).toString()
                selectByMouse: true
            }

            QQC2.Button {
                icon.name: "document-open-folder"
                text: i18n("Choose…")
                onClicked: folderDialog.open()

                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: i18n("Choose folder")
            }
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Folder view:")
            Layout.fillWidth: true
            visible: showFolderViewCheckBox.checked
            wrapMode: Text.WordWrap
            text: i18n("If no folder is selected, the Downloads folder is used. Drag folders from the file manager onto the Dock to add more stacks.")
            opacity: 0.78
        }

        FolderDialog {
            id: folderDialog

            title: i18n("Choose Folder for the Dock")
            currentFolder: folderUrlField.text.length > 0
                ? folderUrlField.text
                : StandardPaths.writableLocation(StandardPaths.DownloadLocation)
            onAccepted: folderUrlField.text = selectedFolder.toString()
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
            Kirigami.FormData.label: i18n("Standalone placement:")
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: i18n("Place this widget directly on the Plasma desktop, not inside a panel. The invisible desktop widget only stores settings; the Dock itself uses a separate transparent window anchored to the selected screen edge and centered along it. BetterBlur can blur that window directly.")
            opacity: 0.78
        }
    }
}
