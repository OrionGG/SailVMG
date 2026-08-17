using Toybox.WatchUi as WatchUi;

// fenix3_hr button mapping (CIQ 1.x behaviors):
//   UP        -> onPreviousPage  (previous screen)
//   DOWN      -> onNextPage      (next screen)
//   START     -> onSelect        (start / pause)
//   hold UP   -> onMenu          (settings)
//   BACK      -> onBack          (default: exit app)
class SailVMGDelegate extends WatchUi.BehaviorDelegate {
    var app;
    var view;

    function initialize(app, view) {
        WatchUi.BehaviorDelegate.initialize();
        me.app = app;
        me.view = view;
    }

    function onPreviousPage() {
        me.view.prevScreen();
        return true;
    }

    function onNextPage() {
        me.view.nextScreen();
        return true;
    }

    function onSelect() {
        me.view.handleStart();
        return true;
    }

    function onMenu() {
        me.view.showSettings();
        return true;
    }

    function onBack() {
        // Like the stock activity apps: while recording, BACK must not drop you
        // out of the app (that would abandon/split the activity). Consume it and
        // stay put -- you stop via START -> Save/Discard. When idle, BACK exits
        // normally.
        if (me.app.model != null && me.app.model.running) {
            return true;  // consume: don't exit mid-activity
        }
        return false;     // idle: allow default OS handling (exit)
    }
}
