using Toybox.WatchUi as WatchUi;
using Toybox.Graphics as Graphics;

class SettingsAvgSecsView extends WatchUi.View {
    var app;
    var value = 5;

    function initialize(app) {
        WatchUi.View.initialize();
        me.app = app;
        me.value = me.app.avgLastSeconds;
    }

    function incr() { me.value += 1; }
    function decr() { me.value = Util.max(1, me.value - 1); }
    function save() { me.app.saveSetting("avgLastSeconds", me.value); }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        var midX = dc.getWidth() / 2;
        dc.drawText(midX, 80, Graphics.FONT_SMALL, "Avg Window: " + me.value + " secs", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
