import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string deviceName: ""
    property string shareUrl: ""

    signal clicked()

    width: Math.max(16, Math.round(parent.width * 0.35))
    height: width
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: -Math.round(width * 0.15)
    z: 100

    Accessible.role: Accessible.Button
    Accessible.name: i18n("Recent share from %1", deviceName)
    Accessible.onPressAction: root.clicked()

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Kirigami.Theme.highlightColor
        border.color: Qt.rgba(1, 1, 1, 0.9)
        border.width: 1

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(parent.width * 0.65)
            height: width
            source: "preferences-kde-connect"
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            mouse.accepted = true;
            root.clicked();
        }
    }
}
