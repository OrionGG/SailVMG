using Toybox.WatchUi as WatchUi;
using Toybox.Graphics as Graphics;
using Toybox.Position as Position;
using Toybox.Sensor as Sensor;
using Toybox.Time as Time;
using Toybox.Timer as Timer;
using Toybox.System as System;
using Toybox.Math as Math;

class SailVMGView extends WatchUi.View {
    var app;
    var screenIndex = 0;
    var lastVmg = null;
    var lastHr = null;
    var lastSog = null;   // current speed over ground (knots)
    var lastCog = null;   // current course over ground (degrees)
    var lastSampleTs = null;
    var timer = null;

    // Transient start/stop confirmation overlay (:start green, :stop red).
    var statusFlash = null;
    var flashTimer = null;
    var afterFlashMenu = false;

    function initialize(params) {
        WatchUi.View.initialize();
        me.app = params[:app];
    }

    function onShow() {
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        if (me.timer == null) {
            me.timer = new Timer.Timer();
            me.timer.start(method(:onTick), 1000, true);
        }
    }

    function onHide() {
        if (me.timer != null) {
            me.timer.stop();
            me.timer = null;
        }
        // Keep GPS on while recording so the FIT keeps logging the track even
        // if a menu is briefly shown; only release it when not recording.
        if (me.app.model == null || !me.app.model.running) {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        }
    }

    // Position/sensor data is read on demand via getInfo(); these callbacks
    // only need to exist to keep the subsystems active.
    function onPosition(info as Position.Info) as Void { }

    function onTick() as Void {
        me.sample(Time.now().value());
        WatchUi.requestUpdate();
    }

    function sample(ts) {
        if (me.lastSampleTs != null && ts == me.lastSampleTs) { return; }
        me.lastSampleTs = ts;

        var pos = Position.getInfo();
        var sensor = Sensor.getInfo();

        var sog = null;
        var cog = null;
        var hr = null;
        if (pos != null && pos.accuracy >= Position.QUALITY_USABLE) {
            sog = pos.speed;    // m/s
            if (pos.heading != null) {
                cog = Math.toDegrees(pos.heading);  // Position.heading is RADIANS
            }
        }
        if (sensor != null) { hr = sensor.heartRate; }
        me.lastHr = hr;

        var vmg = null;
        if (sog != null && cog != null) {
            vmg = VmgCalculator.computeVmg(sog, cog, me.app.twd);
        }

        me.lastVmg = vmg;
        me.lastSog = (sog != null) ? sog * 1.9438 : null;   // m/s -> knots
        me.lastCog = cog;                                    // degrees (0..360 at draw)
        me.app.model.addSample(ts, vmg, me.app.twd, hr, me.app.minAbsVmg);
    }

    function prevScreen() {
        me.screenIndex = (me.screenIndex + 2) % 3;
        WatchUi.requestUpdate();
    }

    function nextScreen() {
        me.screenIndex = (me.screenIndex + 1) % 3;
        WatchUi.requestUpdate();
    }

    function handleStart() {
        if (!me.app.model.running) {
            me.app.model.reset();
            me.app.model.startRecording();
            Notify.start();
            me.showFlash(:start, 1500);
        } else {
            // Stop (like the stock apps): pause the activity (timer freezes,
            // logging stops), vibrate + red ring/square for ~2s, then open the
            // Resume / Save / Exit menu.
            me.app.model.pauseRecording();
            Notify.stop();
            me.afterFlashMenu = true;
            me.showFlash(:stop, 2000);
        }
    }

    function showSettings() {
        WatchUi.pushView(new SettingsMenu(), new SettingsMenuDelegate(me.app), WatchUi.SLIDE_UP);
    }

    // Brief green (start) / red (stop) confirmation, like the stock apps.
    function showFlash(kind, durationMs) {
        me.statusFlash = kind;
        if (me.flashTimer != null) { me.flashTimer.stop(); }
        me.flashTimer = new Timer.Timer();
        me.flashTimer.start(method(:clearFlash), durationMs, false);
        WatchUi.requestUpdate();
    }

    function clearFlash() as Void {
        me.statusFlash = null;
        if (me.flashTimer != null) { me.flashTimer.stop(); me.flashTimer = null; }
        if (me.afterFlashMenu) {
            // Safe now: the menu auto-dismisses and its onMenuItem no longer
            // popViews, so pushing it from this timer callback won't over-pop.
            me.afterFlashMenu = false;
            WatchUi.pushView(new PauseMenu(), new PauseMenuDelegate(me.app, me), WatchUi.SLIDE_UP);
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        if (me.statusFlash != null) {
            me.drawStatusFlash(dc);
            return;
        }
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        if (me.screenIndex == 0) {
            me.drawScreen1(dc);
        } else if (me.screenIndex == 1) {
            me.drawScreen2(dc);
        } else {
            me.drawScreen3(dc);
        }
    }

    // Full-screen start/stop indicator: coloured ring around the watch edge plus
    // a centre glyph — green play triangle for start, red square for stop.
    function drawStatusFlash(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var isStart = (me.statusFlash == :start);
        var color = isStart ? Graphics.COLOR_GREEN : Graphics.COLOR_RED;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Red/green ring around the edge of the watch
        dc.setColor(color, Graphics.COLOR_BLACK);
        dc.setPenWidth(9);
        dc.drawCircle(cx, cy, (w / 2) - 6);
        dc.setPenWidth(1);

        // Centre glyph
        if (isStart) {
            var t = h * 14 / 100;
            dc.fillPolygon([[cx - t / 2, cy - t], [cx - t / 2, cy + t], [cx + t, cy]]);
        } else {
            var s = h * 13 / 100;
            dc.fillRectangle(cx - s, cy - s, 2 * s, 2 * s);
        }
    }

    function drawScreen1(dc) {
        var minAbs = me.app.minAbsVmg;
        var displayV = null;
        var frozen = false;

        if (me.lastVmg != null && me.lastVmg > 0 && me.lastVmg.abs() >= minAbs) {
            displayV = me.lastVmg;
        } else {
            displayV = me.app.model.getLastPositive();
            if (displayV != null) { frozen = true; }
        }

        var vmgText = (displayV == null) ? "--" : displayV.format("%.2f");

        var avgSecs = me.app.model.avgPositiveSecs(me.app.avgLastSeconds);
        var avgMins = me.app.model.avgPositiveMins(me.app.avgLastMinutes);
        var avgSecsText = (avgSecs == null) ? "--" : avgSecs.format("%.2f");
        var avgMinsText = (avgMins == null) ? "--" : avgMins.format("%.2f");

        me.drawGrid(dc, "VMG", vmgText, frozen, "AVG VMG Secs", "AVG VMG Mins",
                    avgSecsText, avgMinsText, "TWD " + me.app.twd.format("%03d"));
        me.drawTopSogCog(dc);
    }

    function drawScreen2(dc) {
        var minAbs = me.app.minAbsVmg;
        var displayV = null;
        var frozen = false;

        if (me.lastVmg != null && me.lastVmg < 0 && me.lastVmg.abs() >= minAbs) {
            displayV = me.lastVmg;
        } else {
            displayV = me.app.model.getLastNegative();
            if (displayV != null) { frozen = true; }
        }

        var vmgText = (displayV == null) ? "--" : "-" + displayV.abs().format("%.2f");

        var negSecs = me.app.model.avgNegativeSecs(me.app.avgLastSeconds);
        var negMins = me.app.model.avgNegativeMins(me.app.avgLastMinutes);
        var negSecsText = (negSecs == null) ? "--" : "-" + negSecs.abs().format("%.2f");
        var negMinsText = (negMins == null) ? "--" : "-" + negMins.abs().format("%.2f");

        me.drawGrid(dc, "-VMG", vmgText, frozen, "-AVG VMG Secs", "-AVG VMG Mins",
                    negSecsText, negMinsText, "TWD " + me.app.twd.format("%03d"));
        me.drawTopSogCog(dc);
    }

    function drawScreen3(dc) {
        var hr = me.lastHr;
        var hrText = (hr == null) ? "--" : hr.format("%d");
        var avg = me.app.model.avgHr();
        var avgText = (avg == null) ? "--" : avg.format("%d");
        var elapsed = me.app.model.elapsedSeconds();
        var timeText = (elapsed == null) ? "0:00" : Util.fmtDuration(elapsed);

        me.drawGrid(dc, "HR", hrText, false, "AVG HR", "TIMER",
                    avgText, timeText, "");
    }

    // Shared grid layout: small title + LARGE value (centre-top), two titled
    // columns split by horizontal + vertical lines, small footer (centre-bottom).
    function drawGrid(dc, title, valueText, frozen, colT1, colT2, colV1, colV2, footerText) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var midX = w / 2;
        var leftX = w * 26 / 100;
        var rightX = w * 74 / 100;
        // Small title + HERO value in the largest number font. The value is
        // vertically centred in the band above the first divider so the taller
        // font can't collide with the line regardless of its exact height.
        // FONT_NUMBER_HOT is the largest number font that actually renders on
        // fenix3_hr (THAI_HOT has no glyphs in the "ww" font set -> blank).
        var valueCy = h * 26 / 100;
        dc.drawText(midX, h * 1 / 100, Graphics.FONT_XTINY, title, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(midX, valueCy, Graphics.FONT_NUMBER_HOT, valueText,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (frozen) {
            // Number fonts have no '*', so draw the "held value" marker separately.
            var half = dc.getTextWidthInPixels(valueText, Graphics.FONT_NUMBER_HOT) / 2;
            dc.drawText(midX + half + 3, valueCy, Graphics.FONT_XTINY, "*",
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Split lines: one horizontal above the columns, one vertical between
        // them, one horizontal below.
        dc.drawLine(w * 12 / 100, h * 46 / 100, w * 88 / 100, h * 46 / 100);
        dc.drawLine(midX, h * 46 / 100, midX, h * 81 / 100);
        dc.drawLine(w * 12 / 100, h * 81 / 100, w * 88 / 100, h * 81 / 100);

        dc.drawText(leftX, h * 48 / 100, Graphics.FONT_XTINY, colT1, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(rightX, h * 48 / 100, Graphics.FONT_XTINY, colT2, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(leftX, h * 56 / 100, Graphics.FONT_NUMBER_MEDIUM, colV1, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(rightX, h * 56 / 100, Graphics.FONT_NUMBER_MEDIUM, colV2, Graphics.TEXT_JUSTIFY_CENTER);

        // Small footer (centre-bottom)
        if (footerText != null && !footerText.equals("")) {
            dc.drawText(midX, h * 89 / 100, Graphics.FONT_TINY, footerText, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Current SOG (left) and COG (right) in the top band, above the upper line —
    // where the reference app shows the time. VMG screens only.
    function drawTopSogCog(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var lx = w * 21 / 100;
        var rx = w * 79 / 100;

        var sogText = (me.lastSog == null) ? "--" : me.lastSog.format("%.1f");
        var cogText = "--";
        if (me.lastCog != null) {
            var c = me.lastCog.toNumber() % 360;
            if (c < 0) { c += 360; }
            cogText = c.format("%d") + "°";
        }

        dc.drawText(lx, h * 28 / 100, Graphics.FONT_XTINY, "SOG", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(lx, h * 35 / 100, Graphics.FONT_TINY, sogText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(rx, h * 28 / 100, Graphics.FONT_XTINY, "COG", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(rx, h * 35 / 100, Graphics.FONT_TINY, cogText, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
