using Toybox.WatchUi as WatchUi;

class PauseMenu extends WatchUi.Menu {
    function initialize() {
        WatchUi.Menu.initialize();
        setTitle("Paused");
        addItem("Resume", :resume);
        addItem("Save", :save);
        addItem("Discard", :discard);
    }
}

class PauseMenuDelegate extends WatchUi.MenuInputDelegate {
    var app;
    var view;

    function initialize(app, view) {
        WatchUi.MenuInputDelegate.initialize();
        me.app = app;
        me.view = view;
    }

    function onMenuItem(item) {
        // The legacy WatchUi.Menu dismisses itself when an item is selected, so
        // we must NOT call popView here (that would pop the data view too and
        // exit the app). Just perform the action; the menu closes on its own.
        if (item == :resume) {
            // Resume feels like a start: un-pause, vibrate + green ring/play,
            // then the menu closes back to the last data screen.
            me.app.model.resumeRecording();
            me.view.resumeCountdown();
            Notify.start();
            me.view.showFlash(:start, 1500);
        } else if (item == :save) {
            me.app.model.saveRecording();
            me.view.resetCountdown();
        } else if (item == :discard) {
            // Confirm before throwing the activity away.
            WatchUi.pushView(new DiscardConfirmMenu(),
                             new DiscardConfirmDelegate(me.app, me.view),
                             WatchUi.SLIDE_UP);
        }
    }
}

// Confirmation for Discard. Defaults to "No" (first item) to avoid accidents.
class DiscardConfirmMenu extends WatchUi.Menu {
    function initialize() {
        WatchUi.Menu.initialize();
        setTitle("Discard?");
        addItem("No", :no);
        addItem("Yes", :yes);
    }
}

class DiscardConfirmDelegate extends WatchUi.MenuInputDelegate {
    var app;
    var view;

    function initialize(app, view) {
        WatchUi.MenuInputDelegate.initialize();
        me.app = app;
        me.view = view;
    }

    function onMenuItem(item) {
        if (item == :no) {
            // Cancel: go back to the Pause menu (Resume / Save / Discard).
            WatchUi.pushView(new PauseMenu(),
                             new PauseMenuDelegate(me.app, me.view),
                             WatchUi.SLIDE_UP);
        } else if (item == :yes) {
            me.app.model.discardRecording();
            me.view.resetCountdown();
        }
    }
}
