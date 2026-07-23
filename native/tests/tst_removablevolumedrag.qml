import QtQuick
import QtTest

TestCase {
    id: testCase

    name: "RemovableVolumeDrag"
    width: 420
    height: 140
    when: windowShown
    visible: true

    readonly property string volumeKey:
        "org.kde.plasma.macosdock.removable-volume"
    property int normalDrops: 0
    property int volumeDrops: 0
    property bool sawVolumeHover: false
    property string droppedUdi: ""

    Rectangle {
        id: source
        x: 0
        y: 20
        width: 48
        height: 48
        color: "steelblue"
        property var dragKeys: []
        property string volumeUdi: "test-volume"

        Item {
            id: dragProxy
            objectName: source.volumeUdi
            width: source.width
            height: source.height
            Drag.hotSpot: Qt.point(width / 2, height / 2)
            Drag.keys: source.dragKeys
            Drag.proposedAction: Qt.MoveAction
            Drag.source: dragProxy
            Drag.supportedActions: Qt.MoveAction
        }

        DragHandler {
            id: dragHandler
            target: dragProxy
            onActiveChanged: {
                if (active) {
                    dragProxy.Drag.start(Qt.MoveAction)
                } else {
                    dragProxy.Drag.drop()
                    dragProxy.x = 0
                    dragProxy.y = 0
                }
            }
        }
    }

    DropArea {
        x: 260
        y: 0
        width: 120
        height: 120

        onEntered: (drag) => {
            if (drag.keys && drag.keys.indexOf(testCase.volumeKey) !== -1) {
                testCase.sawVolumeHover = true
            }
        }
        onDropped: (drop) => {
            if (drop.keys && drop.keys.indexOf(testCase.volumeKey) !== -1) {
                testCase.volumeDrops += 1
                testCase.droppedUdi = drop.source ? drop.source.objectName : ""
                drop.acceptProposedAction()
            } else {
                testCase.normalDrops += 1
                drop.acceptProposedAction()
            }
        }
    }

    function resetResults() {
        normalDrops = 0
        volumeDrops = 0
        sawVolumeHover = false
        droppedUdi = ""
    }

    function test_normalDropIsNotFiltered() {
        resetResults()
        source.dragKeys = []

        mouseDrag(source, 24, 24, 300, 0, Qt.LeftButton)
        wait(25)

        compare(normalDrops, 1)
        compare(volumeDrops, 0)
        verify(!sawVolumeHover)
    }

    function test_volumeDropReachesTarget() {
        resetResults()
        source.dragKeys = [volumeKey]

        mouseDrag(source, 24, 24, 300, 0, Qt.LeftButton)
        wait(25)

        compare(normalDrops, 0)
        compare(volumeDrops, 1)
        verify(sawVolumeHover)
        compare(droppedUdi, source.volumeUdi)
        compare(dragProxy.x, 0)
        compare(dragProxy.y, 0)
    }
}
