using Toybox.WatchUi as WatchUi;
using Toybox.Graphics as Graphics;

// Step 1: compass snap menu. UP/DOWN scroll the 8 options, START selects one.
class TWDCompassMenu extends WatchUi.Menu {
    function initialize() {
        WatchUi.Menu.initialize();
        setTitle("Set TWD");
        addItem("N (0°)", :d0);
        addItem("NE (45°)", :d45);
        addItem("E (90°)", :d90);
        addItem("SE (135°)", :d135);
        addItem("S (180°)", :d180);
        addItem("SW (225°)", :d225);
        addItem("W (270°)", :d270);
        addItem("NW (315°)", :d315);
    }
}

class TWDCompassDelegate extends WatchUi.MenuInputDelegate {
    var app;

    function initialize(app) {
        WatchUi.MenuInputDelegate.initialize();
        me.app = app;
    }

    function onMenuItem(item) {
        var deg = degreeFor(item);
        if (deg != null) {
            var view = new SettingsTWDView(me.app, deg);
            WatchUi.pushView(view, new TWDAdjustDelegate(view), WatchUi.SLIDE_LEFT);
        }
    }

    function degreeFor(item) {
        if (item == :d0)   { return 0; }
        if (item == :d45)  { return 45; }
        if (item == :d90)  { return 90; }
        if (item == :d135) { return 135; }
        if (item == :d180) { return 180; }
        if (item == :d225) { return 225; }
        if (item == :d270) { return 270; }
        if (item == :d315) { return 315; }
        return null;
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
//   START -> save and return to the Settings menu (pop adjust + compass menu)
//   BACK  -> return to the compass snap menu (pop adjust only)
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
        // The compass menu already dismissed itself on selection, so a single
        // pop returns to the data screen (a double pop would exit the app).
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
