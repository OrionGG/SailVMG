using Toybox.WatchUi as WatchUi;

class PauseMenu extends WatchUi.Menu {
    function initialize() {
        WatchUi.Menu.initialize();
        setTitle("Paused");
        addItem("Resume", :resume);
        addItem("Save", :save);
        addItem("Exit", :exit);
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
            // nothing to do — menu closes, recording continues
        } else if (item == :save) {
            me.app.model.saveRecording();
        } else if (item == :exit) {
            me.app.model.discardRecording();
        }
    }
}
