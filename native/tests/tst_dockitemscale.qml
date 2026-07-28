import QtQuick
import QtTest
import "../../contents/ui"

// Die Vergroesserung lief frueher ueber Qt's SpringAnimation. Die integriert
// auf einem festen 16-ms-Raster und liefert deshalb hoechstens rund 62
// Wertaenderungen pro Sekunde - auf einem 120-Hz-Bildschirm wiederholt jedes
// zweite Bild den vorherigen Wert. Diese Tests halten fest, dass die Feder
// jetzt mit der echten Bildabstandszeit rechnet und bei jeder
// Bildwiederholrate dieselbe Bewegung ergibt.
TestCase {
    name: "DockItemScale"

    Component {
        id: itemComponent

        DockItem {
            // Der Takt wird im Test von Hand gestellt.
            scaleFollowEnabled: false
        }
    }

    function makeItem(response, damping) {
        var item = createTemporaryObject(itemComponent, this);
        verify(item);
        item.scaleResponse = response;
        item.scaleDamping = damping;
        item.currentScale = 1.0;
        item.scaleVelocity = 0.0;
        item.scaleSettled = true;
        return item;
    }

    // Laesst die Feder genau `seconds` lang laufen und teilt die Zeit dabei in
    // Bilder der Laenge `stepSeconds`. Ein angebrochenes letztes Bild wird
    // verkuerzt, damit alle Bildwiederholraten dieselbe Zeitspanne simulieren
    // und der Vergleich nur noch den Integrator misst.
    function run(item, seconds, stepSeconds) {
        var remaining = seconds;
        while (remaining > 1.0e-9) {
            var step = Math.min(stepSeconds, remaining);
            item.advanceScale(step);
            remaining -= step;
        }
    }

    function test_followsTargetAndSettlesExactly() {
        var item = makeItem(50.0, 1.0);
        item.targetScale = 1.45;
        verify(!item.scaleSettled);

        run(item, 0.5, 1.0 / 120.0);

        verify(item.scaleSettled);
        compare(item.currentScale, 1.45);
        compare(item.scaleVelocity, 0.0);
    }

    // Der eigentliche Regressionstest: dieselbe Zeitspanne bei 60, 120 und
    // 144 Hz muss praktisch dieselbe Vergroesserung ergeben.
    function test_sameMotionAtEveryRefreshRate() {
        var elapsed = 0.06;
        var at60 = makeItem(50.0, 1.0);
        var at120 = makeItem(50.0, 1.0);
        var at144 = makeItem(50.0, 1.0);
        at60.targetScale = 1.45;
        at120.targetScale = 1.45;
        at144.targetScale = 1.45;

        run(at60, elapsed, 1.0 / 60.0);
        run(at120, elapsed, 1.0 / 120.0);
        run(at144, elapsed, 1.0 / 144.0);

        // Mitten in der Bewegung, nicht schon am Ziel angekommen. Die gemessene
        // Abweichung liegt bei 0.0003 (60 Hz) und 0.0012 (144 Hz) von 0.45 Hub.
        verify(at120.currentScale > 1.1);
        verify(at120.currentScale < 1.45);
        fuzzyCompare(at60.currentScale, at120.currentScale, 0.003);
        fuzzyCompare(at144.currentScale, at120.currentScale, 0.003);
    }

    function test_criticalDampingDoesNotOvershoot() {
        var item = makeItem(50.0, 1.0);
        item.targetScale = 1.45;

        var highest = 1.0;
        for (var i = 0; i < 120; ++i) {
            item.advanceScale(1.0 / 120.0);
            highest = Math.max(highest, item.currentScale);
        }
        verify(highest <= 1.45 + 1.0e-6);
    }

    function test_lowDampingOvershoots() {
        var item = makeItem(50.0, 0.2);
        item.targetScale = 1.45;

        var highest = 1.0;
        for (var i = 0; i < 120; ++i) {
            item.advanceScale(1.0 / 120.0);
            highest = Math.max(highest, item.currentScale);
        }
        verify(highest > 1.45);
    }

    // Ein verschlucktes Bild oder eine Ruhephase darf die explizite
    // Integration nicht zum Aufschwingen bringen.
    function test_longFrameGapStaysStable() {
        var item = makeItem(60.0, 1.0);
        item.targetScale = 1.45;

        item.advanceScale(0.5);
        verify(item.currentScale >= 1.0);
        verify(item.currentScale <= 1.45 + 1.0e-6);

        run(item, 0.5, 1.0 / 120.0);
        compare(item.currentScale, 1.45);
    }

    function test_targetChangeMidFlightKeepsVelocity() {
        var item = makeItem(50.0, 1.0);
        item.targetScale = 1.45;
        run(item, 0.03, 1.0 / 120.0);

        var movingVelocity = item.scaleVelocity;
        verify(movingVelocity > 0.0);

        // Ein neues Ziel setzt die Feder nicht zurueck, sie laeuft mit ihrer
        // aufgebauten Geschwindigkeit weiter. Genau das ging bei einer
        // zeitbasierten Kurve verloren.
        item.targetScale = 1.30;
        verify(!item.scaleSettled);
        compare(item.scaleVelocity, movingVelocity);

        run(item, 0.5, 1.0 / 120.0);
        compare(item.currentScale, 1.30);
    }

    function test_constantTargetNeverTicks() {
        var item = makeItem(50.0, 1.0);
        verify(item.scaleSettled);

        // Symbole im unvergroesserten Basisfenster haben ein festes Ziel.
        item.targetScale = 1.0;
        verify(item.scaleSettled);
    }
}
