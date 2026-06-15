using Toybox.WatchUi as WatchUi;
using Toybox.Graphics as Graphics;

class SettingsMinVmgView extends WatchUi.View {
    var app;
    var value = 0.5;

    function initialize(app) {
        WatchUi.View.initialize();
        me.app = app;
        me.value = me.app.minAbsVmg;
    }

    function incr() { me.value += 0.5; }
    function decr() { me.value = Util.max(0.0, me.value - 0.5); }
    function save() { me.app.saveSetting("minAbsVmg", me.value); }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        var midX = dc.getWidth() / 2;
        dc.drawText(midX, 80, Graphics.FONT_SMALL, "Min ABS VMG: " + me.value.format("%.1f") + " kts", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
