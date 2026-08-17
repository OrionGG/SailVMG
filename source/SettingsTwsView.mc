using Toybox.WatchUi as WatchUi;
using Toybox.Graphics as Graphics;

// Pick the True Wind Speed band. Same input pattern as the other value screens
// (SettingsValueDelegate): UP/DOWN change the band, START saves, BACK cancels.
// The band list lives on the app (SailVMGApp.twsBands) so it's defined once.
class SettingsTwsView extends WatchUi.View {
    var app;
    var index = 0;

    function initialize(app) {
        WatchUi.View.initialize();
        me.app = app;
        me.index = me.app.tws;
    }

    function incr() { me.index = Util.min(me.app.twsBands.size() - 1, me.index + 1); }
    function decr() { me.index = Util.max(0, me.index - 1); }
    function save() { me.app.saveSetting("tws", me.index); }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        var midX = dc.getWidth() / 2;
        // Text font (not a NUMBER font) so the "kts" letters render.
        dc.drawText(midX, 70, Graphics.FONT_SMALL, "TWS band", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(midX, 100, Graphics.FONT_MEDIUM, me.app.twsBands[me.index],
                    Graphics.TEXT_JUSTIFY_CENTER);
    }
}
