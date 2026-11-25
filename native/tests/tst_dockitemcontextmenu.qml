import QtQuick
import QtQuick.Controls as QQC2
import QtTest
import org.kde.plasma.core as PlasmaCore
import "../../contents/ui"

TestCase {
    id: testCase

    name: "DockItemContextMenu"
    width: 1400
    height: 140
    when: windowShown
    visible: true

    Item {
        id: overlayHost
        anchors.fill: parent

        Item {
            id: contextMenuAnchor
            width: 1
            height: 1
            enabled: false
        }

        QQC2.Menu {
            id: powerMenu
            QQC2.MenuItem { text: "Shut Down" }
        }

        Item {
            id: iconBand
            x: 0
            y: 28
            width: parent.width
            height: 77

            DockItem {
                id: rightPowerItem
                inOverlay: true
                baseSize: 48
                targetScale: 1.5
                currentScale: 1.5
                scaleFollowEnabled: false
                crossIconExtent: 72
                location: PlasmaCore.Types.BottomEdge
                x: 1260
                y: 0
                appName: "Power / Session"
            }

            DockItem {
                id: unmagnifiedBottomItem
                inOverlay: true
                baseSize: 48
                targetScale: 1.0
                currentScale: 1.0
                scaleFollowEnabled: false
                crossIconExtent: 72
                location: PlasmaCore.Types.BottomEdge
                x: 900
                y: 0
                appName: "Trash"
            }
        }
    }

    function test_contextMenuRectTracksRightSidePowerButton() {
        var rect = rightPowerItem.contextMenuRectIn(overlayHost);
        compare(rect.x, 1260);
        compare(rect.y, 28);
        compare(rect.width, 72);
        compare(rect.height, 72);

        contextMenuAnchor.x = rect.x;
        contextMenuAnchor.y = rect.y;
        contextMenuAnchor.width = rect.width;
        contextMenuAnchor.height = rect.height;
        powerMenu.parent = contextMenuAnchor;

        var sceneTopLeft = powerMenu.parent.mapToItem(null, 0, 0);
        compare(sceneTopLeft.x, 1260);
        compare(sceneTopLeft.y, 28);
        compare(powerMenu.parent.width, 72);
        compare(powerMenu.parent.height, 72);
    }

    function test_contextMenuRectUsesActualIconBoundsWhenUnmagnified() {
        var rect = unmagnifiedBottomItem.contextMenuRectIn(overlayHost);
        compare(rect.x, 900);
        // Bottom-edge unmagnified 48px icon sits at y = 72 - 48 = 24 inside iconBand (y = 28).
        compare(rect.y, 28 + 24);
        compare(rect.width, 48);
        compare(rect.height, 48);
    }
}
