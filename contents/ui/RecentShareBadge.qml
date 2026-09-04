import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string deviceName: ""
    property string previewText: ""

    signal clicked()

    width: Math.max(18, Math.round(parent.width * 0.34))
    height: width
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: -Math.round(width * 0.12)
    z: 100

    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: i18n("Recent share from %1", deviceName)
    Accessible.description: previewText
    Accessible.onPressAction: root.clicked()

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                || event.key === Qt.Key_Space) {
            event.accepted = true;
            root.clicked();
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Kirigami.Theme.highlightColor
        border.color: Kirigami.Theme.backgroundColor
        border.width: 1

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(parent.width * 0.64)
            height: width
            source: "preferences-kde-connect"
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            mouse.accepted = true;
            root.clicked();
        }
    }

    QQC2.ToolTip.visible: mouseArea.containsMouse
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
    QQC2.ToolTip.text: previewText.length > 0
        ? i18n("Recent share from %1", deviceName) + "\n" + previewText
        : i18n("Recent share from %1", deviceName)
}
