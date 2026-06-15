using Toybox.Application as App;
using Toybox.WatchUi as WatchUi;

class SailVMGApp extends App.AppBase {
    var model;
    var view;
    var delegate;

    // Settings (persisted in the Object Store via get/setProperty).
    var twd = 0;
    var minAbsVmg = 0.5;
    var avgLastSeconds = 5;
    var avgLastMinutes = 1;

    function initialize() {
        App.AppBase.initialize();

        var t = getProperty("twd");
        me.twd = (t == null) ? 0 : t;
        var m = getProperty("minAbsVmg");
        me.minAbsVmg = (m == null) ? 0.5 : m;
        var s = getProperty("avgLastSeconds");
        me.avgLastSeconds = (s == null) ? 5 : s;
        var n = getProperty("avgLastMinutes");
        me.avgLastMinutes = (n == null) ? 1 : n;

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
        }

        if (me.model != null &&
            (key.equals("avgLastSeconds") || key.equals("avgLastMinutes"))) {
            me.model.updateWindowSettings(me.avgLastSeconds, me.avgLastMinutes);
        }
    }
}
