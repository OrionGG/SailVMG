using Toybox.WatchUi as WatchUi;
using Toybox.Graphics as Graphics;

// Step 1: compass snap list. Rebuilt as a plain View (NOT a legacy WatchUi.Menu)
// so the two-step TWD flow can no longer over-pop and exit the app mid-activity.
// A legacy Menu auto-dismisses itself on selection; chaining two of them
// (Settings -> compass) made the return pop-count ambiguous on-device, which
// closed the app -> the OS then auto-saved the in-progress recording, splitting
// the activity in two. A plain View has no auto-dismiss, so every pop is
// explicit and deterministic.
//   UP / DOWN -> move the highlight
//   START     -> open the fine-adjust screen for the highlighted cardinal
//   BACK      -> return to the data screen
class TWDCompassView extends WatchUi.View {
    var app;
    var index = 0;
    var labels = ["N (0°)", "NE (45°)", "E (90°)", "SE (135°)",
                  "S (180°)", "SW (225°)", "W (270°)", "NW (315°)"];
    var degrees = [0, 45, 90, 135, 180, 225, 270, 315];

    function initialize(app) {
        WatchUi.View.initialize();
        me.app = app;
        me.index = me.nearestIndex(app.twd);
    }

    // Start on the cardinal closest to the current TWD (circular distance so
    // 350 deg snaps to N, not NW).
    function nearestIndex(deg) {
        var best = 0;
        var bestd = 360;
        for (var i = 0; i < me.degrees.size(); i += 1) {
            var diff = (me.degrees[i] - deg).abs();
            var d = (diff > 180) ? (360 - diff) : diff;
            if (d < bestd) { best = i; bestd = d; }
        }
        return best;
    }

    function prev() { me.index = (me.index + me.labels.size() - 1) % me.labels.size(); }
    function next() { me.index = (me.index + 1) % me.labels.size(); }
    function selectedDegree() { return me.degrees[me.index]; }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var midX = w / 2;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();

        dc.drawText(midX, h * 3 / 100, Graphics.FONT_TINY, "Set TWD", Graphics.TEXT_JUSTIFY_CENTER);

        var startY = h * 16 / 100;
        var rowH = h * 10 / 100;
        for (var i = 0; i < me.labels.size(); i += 1) {
            var y = startY + i * rowH;
            if (i == me.index) {
                // Highlighted row: inverted (white text on a black bar).
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
                dc.fillRectangle(w * 10 / 100, y, w * 80 / 100, rowH);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            } else {
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
            }
            dc.drawText(midX, y + rowH / 2, Graphics.FONT_XTINY, me.labels[i],
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}

// Input for the compass list. A plain BehaviorDelegate, so pushes/pops are
// explicit and can't over-pop into an app exit.
class TWDCompassSelectDelegate extends WatchUi.BehaviorDelegate {
    var view;

    function initialize(view) {
        WatchUi.BehaviorDelegate.initialize();
        me.view = view;
    }

    function onPreviousPage() { me.view.prev(); WatchUi.requestUpdate(); return true; }
    function onNextPage()     { me.view.next(); WatchUi.requestUpdate(); return true; }

    function onSelect() {
        var fine = new SettingsTWDView(me.view.app, me.view.selectedDegree());
        WatchUi.pushView(fine, new TWDAdjustDelegate(fine), WatchUi.SLIDE_LEFT);
        return true;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);   // back to the data screen
        return true;
    }
}

// Step 2: fine adjust. UP +1deg, DOWN -1deg (wrapping), START saves, BACK returns.
class SettingsTWDView extends WatchUi.View {
    var app;
    var degree = 0;
    var snapPoints = [0, 45, 90, 135, 180, 225, 270, 315];

    function initialize(app, initialDeg) {
        WatchUi.View.initialize();
        me.app = app;
        me.degree = initialDeg;
    }

    function incr() { me.degree = (me.degree + 1) % 360; }
    function decr() { me.degree = (me.degree + 359) % 360; }
    function save() { me.app.saveSetting("twd", me.degree); }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        var midX = dc.getWidth() / 2;
        var text = "TWD: " + me.degree.format("%03d") + "° (" + me.findNearestSnap(me.degree) + ")";
        dc.drawText(midX, 80, Graphics.FONT_SMALL, text, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(midX, 120, Graphics.FONT_TINY, "UP/DOWN +-1   START save", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function findNearestSnap(deg) {
        var best = me.snapPoints[0];
        var bestd = 360;
        for (var i = 0; i < me.snapPoints.size(); i += 1) {
            var s = me.snapPoints[i];
            // circular (wrap-around) distance: 350 deg is 10 deg from N, not 350
            var diff = (s - deg).abs();
            var d = (diff > 180) ? (360 - diff) : diff;
            if (d < bestd) { best = s; bestd = d; }
        }
        var labelMap = {
            0 => "N", 45 => "NE", 90 => "E", 135 => "SE",
            180 => "S", 225 => "SW", 270 => "W", 315 => "NW"
        };
        return labelMap[best];
    }
}

// Input for the fine-adjust screen.
//   UP    -> +1 degree
//   DOWN  -> -1 degree
//   START -> save and return to the data screen (pop fine-adjust + compass)
//   BACK  -> return to the compass list (pop fine-adjust only)
// The stack here is always [data, compass, fine-adjust], so the two pops on save
// land exactly on the data screen and can never over-pop into an app exit.
class TWDAdjustDelegate extends WatchUi.BehaviorDelegate {
    var view;

    function initialize(view) {
        WatchUi.BehaviorDelegate.initialize();
        me.view = view;
    }

    function onPreviousPage() {
        me.view.incr();
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        me.view.decr();
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect() {
        me.view.save();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);   // pop fine-adjust
        WatchUi.popView(WatchUi.SLIDE_RIGHT);   // pop compass -> back to data
        return true;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);   // back to the compass list
        return true;
    }
}
