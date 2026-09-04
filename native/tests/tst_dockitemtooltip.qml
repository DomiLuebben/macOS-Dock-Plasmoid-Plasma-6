import QtQuick
import QtTest
import org.kde.plasma.core as PlasmaCore
import "../../contents/ui"

TestCase {
    id: testCase

    name: "DockItemTooltip"
    width: 400
    height: 300
    when: windowShown
    visible: true

    DockItem {
        id: dockItem
        x: 50
        y: 100
        baseSize: 48
        appName: "Test Application"
        inOverlay: true
        location: PlasmaCore.Types.BottomEdge
    }

    DockItem {
        id: emptyNameItem
        x: 150
        y: 100
        baseSize: 48
        appName: ""
        inOverlay: true
    }

    function init() {
        dockItem.appName = "Test Application";
        dockItem.inOverlay = true;
        dockItem.isDragging = false;
        dockItem.isRunning = false;
        dockItem.windowsList = [];
        dockItem.setPreviewOpen(false);
    }

    function cleanup() {
        dockItem.setPreviewOpen(false);
    }

    function test_titleTooltipAvailability() {
        verify(dockItem.hasTitleTooltip, "Item with appName must have hasTitleTooltip true");
        verify(!dockItem.hasWindowPreviews, "Not running item must not have window previews");
        verify(dockItem.tooltipOrPreviewAvailable, "Item with title and inOverlay must be available");

        // When dragging, tooltip must not be available
        dockItem.isDragging = true;
        verify(!dockItem.tooltipOrPreviewAvailable, "Dragging item must not be available for tooltip");
        dockItem.isDragging = false;

        // When not in overlay, tooltip must not be available
        dockItem.inOverlay = false;
        verify(!dockItem.tooltipOrPreviewAvailable, "Base window item (not in overlay) must not show tooltip");
        dockItem.inOverlay = true;

        // When appName is empty, title tooltip must not be available
        verify(!emptyNameItem.hasTitleTooltip, "Item with empty name must not have title tooltip");
        verify(!emptyNameItem.tooltipOrPreviewAvailable, "Item with empty name must not be available");
    }

    function test_windowPreviewsDetection() {
        dockItem.isRunning = true;
        dockItem.previewAvailable = true;
        dockItem.windowsList = [];
        verify(!dockItem.hasWindowPreviews, "Running item with empty windowsList must not have window previews");

        dockItem.windowsList = [{ winId: "12345", title: "Window 1", isActive: true }];
        verify(dockItem.hasWindowPreviews, "Running item with open windows must have hasWindowPreviews true");

        dockItem.previewAvailable = false;
        verify(!dockItem.hasWindowPreviews, "Item with previewAvailable false must not have window previews");
    }

    // Abbild der Ableitungskette aus main.qml. Deklariert dort ein abgeleiteter
    // Typ "inOverlay" erneut, nimmt der Schatten die Zuweisung entgegen und
    // DockItem liest weiter seine eigene Vorgabe — die Tooltips von Ordnern und
    // Papierkorb fielen dadurch stumm aus. Diese Faelle laufen deshalb ueber die
    // Kette, nicht ueber ein nacktes DockItem.
    component AuxiliaryDelegate: DockItem {
        inOverlay: false
    }

    component UtilityDelegate: AuxiliaryDelegate {}

    UtilityDelegate {
        id: folderOverlayItem
        baseSize: 48
        appName: "Dokumente"
        inOverlay: true
        location: PlasmaCore.Types.BottomEdge
    }

    UtilityDelegate {
        id: folderBaseItem
        baseSize: 48
        appName: "Dokumente"
        location: PlasmaCore.Types.BottomEdge
    }

    DockItem {
        id: baseWindowTask
        baseSize: 48
        appName: "Test Application"
        location: PlasmaCore.Types.BottomEdge
    }

    function test_auxiliaryDelegateChainKeepsOverlayFlag() {
        verify(folderOverlayItem.tooltipOrPreviewAvailable,
            "Ordner/Papierkorb im Overlay muessen ein Titel-Tooltip bekommen");
        verify(!folderBaseItem.tooltipOrPreviewAvailable,
            "Dieselben Items im baseWindow duerfen kein Tooltip zeigen");
    }

    function test_baseWindowItemIsSilentByDefault() {
        verify(!baseWindowTask.inOverlay,
            "DockItem muss ohne ausdrueckliche Zuweisung ausserhalb des Overlays liegen");
        verify(!baseWindowTask.tooltipOrPreviewAvailable,
            "Ein DockItem ohne inOverlay-Zuweisung darf kein Tooltip oeffnen");
    }

    function test_positionPreviewWindowAboveBottomDock() {
        dockItem.location = PlasmaCore.Types.BottomEdge;
        dockItem.setPreviewOpen(true);
        verify(dockItem.previewOpen, "previewOpen should be true after setPreviewOpen(true)");

        var previewWin = dockItem.previewWindowObject;
        verify(previewWin !== null, "previewWindowObject must exist when previewOpen is true");

        // Position preview window
        dockItem.positionPreviewWindow();

        // On a bottom dock, placementBottom is distance from screen bottom to tooltip bottom
        // It must be strictly positive (anchored above the icon, not below it)
        verify(previewWin.placementBottom > 0,
            "placementBottom must be > 0 to place tooltip above the bottom dock icon");

        // Clicking the item must close the tooltip
        mouseClick(dockItem, dockItem.width / 2, dockItem.height / 2, Qt.LeftButton);
        verify(!dockItem.previewOpen, "Clicking dock item must close preview/tooltip");
    }
}
