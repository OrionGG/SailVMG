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
        if (item == :resume) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (item == :save) {
            me.app.model.saveRecording();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (item == :exit) {
            me.app.model.discardRecording();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
    }
}
