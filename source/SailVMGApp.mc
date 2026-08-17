using Toybox.Application as App;
using Toybox.WatchUi as WatchUi;

class SailVMGApp extends App.AppBase {
    var model;
    var view;
    var delegate;

    // Settings (persisted in the Object Store via get/setProperty).
    var twd = 0;
    var minAbsVmg = 0.5;
    var avgLastSeconds = 30;
    var avgLastMinutes = 3;
    // True Wind Speed band (index into twsBands). Selected only for now; not yet
    // shown or used, but stored centrally so it's ready to wire up.
    var tws = 0;
    var twsBands = ["4-8 kts", "8-12 kts", "12-15 kts", "15-18 kts"];

    // Polar TARGET SOG (kn) per TWS band, indexed like twsBands.
    //   band       upwind  downwind
    //   4-8 kts    4.11    4.37
    //   8-12 kts   4.64    5.49
    //   12-15 kts  5.08    7.56
    //   15-18 kts  4.91    8.71
    var twsUpwindSog   = [4.11, 4.64, 5.08, 4.91];
    var twsDownwindSog = [4.37, 5.49, 7.56, 8.71];

    function twsLabel() { return me.twsBands[me.tws]; }

    // Target SOG for the selected band, for the current point of sail.
    function targetSog(upwind) {
        return upwind ? me.twsUpwindSog[me.tws] : me.twsDownwindSog[me.tws];
    }

    function initialize() {
        App.AppBase.initialize();

        var t = getProperty("twd");
        me.twd = (t == null) ? 0 : t;
        var m = getProperty("minAbsVmg");
        me.minAbsVmg = (m == null) ? 0.5 : m;
        var s = getProperty("avgLastSeconds");
        me.avgLastSeconds = (s == null) ? 30 : s;
        var n = getProperty("avgLastMinutes");
        me.avgLastMinutes = (n == null) ? 3 : n;
        var ws = getProperty("tws");
        me.tws = (ws == null) ? 0 : ws;

        me.model = new DataModel({
            :avgLastSeconds => me.avgLastSeconds,
            :avgLastMinutes => me.avgLastMinutes
        });
    }

    // CIQ 1.x entry point: return [view, delegate].
    function getInitialView() {
        me.view = new SailVMGView({:app => me});
        me.delegate = new SailVMGDelegate(me, me.view);
        return [me.view, me.delegate];
    }

    function saveSetting(key, value) {
        setProperty(key, value);
        if (key.equals("twd")) {
            me.twd = value;
        } else if (key.equals("minAbsVmg")) {
            me.minAbsVmg = value;
        } else if (key.equals("avgLastSeconds")) {
            me.avgLastSeconds = value;
        } else if (key.equals("avgLastMinutes")) {
            me.avgLastMinutes = value;
        } else if (key.equals("tws")) {
            me.tws = value;
        }

        if (me.model != null &&
            (key.equals("avgLastSeconds") || key.equals("avgLastMinutes"))) {
            me.model.updateWindowSettings(me.avgLastSeconds, me.avgLastMinutes);
        }
    }
}
