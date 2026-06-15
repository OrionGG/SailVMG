using Toybox.WatchUi as WatchUi;

class SettingsMenu extends WatchUi.Menu {
    function initialize() {
        WatchUi.Menu.initialize();
        setTitle("Settings");
        addItem("Set TWD", :twd);
        addItem("Set Min ABS VMG", :minVmg);
        addItem("Set AVG Last Seconds", :avgSec);
        addItem("Set AVG Last Minutes", :avgMin);
    }
}

class SettingsMenuDelegate extends WatchUi.MenuInputDelegate {
    var app;

    function initialize(app) {
        WatchUi.MenuInputDelegate.initialize();
        me.app = app;
    }

    function onMenuItem(item) {
        // TWD uses a two-step flow: compass snap menu -> fine adjust.
        if (item == :twd) {
            WatchUi.pushView(new TWDCompassMenu(), new TWDCompassDelegate(me.app), WatchUi.SLIDE_LEFT);
            return;
        }

        var view = null;
        if (item == :minVmg) {
            view = new SettingsMinVmgView(me.app);
        } else if (item == :avgMin) {
            view = new SettingsAvgMinView(me.app);
        } else if (item == :avgSec) {
            view = new SettingsAvgSecsView(me.app);
        }
        if (view != null) {
            WatchUi.pushView(view, new SettingsValueDelegate(view), WatchUi.SLIDE_LEFT);
        }
    }
}

// Shared input handler for the value-adjustment screens.
//   UP    -> incr      DOWN  -> decr
//   START -> save+pop  BACK  -> cancel+pop
class SettingsValueDelegate extends WatchUi.BehaviorDelegate {
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
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
