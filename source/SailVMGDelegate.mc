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
        return false; // allow default OS handling (exit)
    }
}
