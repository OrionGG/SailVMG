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
    var lastSampleTs = null;
    var timer = null;

    // Transient start/stop confirmation overlay (:start green, :stop red).
    var statusFlash = null;
    var flashTimer = null;

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
            me.showFlash(:start);
        } else {
            // Pressing START while recording = Stop: beep/vibrate, then open the
            // Resume / Save / Exit menu. Pushed straight from this input handler
            // (never from a Timer callback, which corrupts the view stack).
            Notify.stop();
            WatchUi.pushView(new PauseMenu(), new PauseMenuDelegate(me.app, me), WatchUi.SLIDE_UP);
        }
    }

    function showSettings() {
        WatchUi.pushView(new SettingsMenu(), new SettingsMenuDelegate(me.app), WatchUi.SLIDE_UP);
    }

    // Brief green (start) / red (stop) confirmation, like the stock apps.
    function showFlash(kind) {
        me.statusFlash = kind;
        if (me.flashTimer != null) { me.flashTimer.stop(); }
        me.flashTimer = new Timer.Timer();
        me.flashTimer.start(method(:clearFlash), 1200, false);
        WatchUi.requestUpdate();
    }

    function clearFlash() as Void {
        me.statusFlash = null;
        if (me.flashTimer != null) { me.flashTimer.stop(); me.flashTimer = null; }
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

    // Full-screen start/stop indicator: coloured circle + play/stop glyph.
    function drawStatusFlash(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var isStart = (me.statusFlash == :start);
        var color = isStart ? Graphics.COLOR_GREEN : Graphics.COLOR_RED;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(color, Graphics.COLOR_BLACK);
        dc.fillCircle(cx, cy, h * 30 / 100);

        dc.setColor(Graphics.COLOR_WHITE, color);
        if (isStart) {
            var t = h * 13 / 100;
            dc.fillPolygon([[cx - t / 2, cy - t], [cx - t / 2, cy + t], [cx + t, cy]]);
        } else {
            var s = h * 10 / 100;
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
        var valueY = h * 10 / 100;

        // Small title + LARGE value (number font), centre-top
        dc.drawText(midX, h * 2 / 100, Graphics.FONT_XTINY, title, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(midX, valueY, Graphics.FONT_NUMBER_MEDIUM, valueText, Graphics.TEXT_JUSTIFY_CENTER);
        if (frozen) {
            // Number fonts have no '*', so draw the "held value" marker separately.
            var half = dc.getTextWidthInPixels(valueText, Graphics.FONT_NUMBER_MEDIUM) / 2;
            dc.drawText(midX + half + 3, valueY, Graphics.FONT_XTINY, "*", Graphics.TEXT_JUSTIFY_LEFT);
        }

        // Split lines: one horizontal above the columns, one vertical between
        // them, one horizontal below.
        dc.drawLine(w * 12 / 100, h * 37 / 100, w * 88 / 100, h * 37 / 100);
        dc.drawLine(midX, h * 37 / 100, midX, h * 73 / 100);
        dc.drawLine(w * 12 / 100, h * 73 / 100, w * 88 / 100, h * 73 / 100);

        dc.drawText(leftX, h * 39 / 100, Graphics.FONT_XTINY, colT1, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(rightX, h * 39 / 100, Graphics.FONT_XTINY, colT2, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(leftX, h * 47 / 100, Graphics.FONT_NUMBER_MEDIUM, colV1, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(rightX, h * 47 / 100, Graphics.FONT_NUMBER_MEDIUM, colV2, Graphics.TEXT_JUSTIFY_CENTER);

        // Small footer (centre-bottom)
        if (footerText != null && !footerText.equals("")) {
            dc.drawText(midX, h * 84 / 100, Graphics.FONT_TINY, footerText, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
