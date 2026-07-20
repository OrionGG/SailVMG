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

    // Screen 4 countdown timer state
    var countdownSecs = 60;
    var countdownRunning = false;

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
        if (me.countdownRunning) {
            if (me.countdownSecs > 0) {
                me.countdownSecs -= 1;
            } else {
                me.countdownSecs = 59;   // after 0 wrap to 59 (..1,0,59,58..)
            }
        }
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
        me.screenIndex = (me.screenIndex + 3) % 4;
        WatchUi.requestUpdate();
    }

    function nextScreen() {
        me.screenIndex = (me.screenIndex + 1) % 4;
        WatchUi.requestUpdate();
    }

    function handleStart() {
        // START behaves the same on every screen: it starts/stops the activity.
        // The screen-4 countdown is tied to that same lifecycle.
        if (!me.app.model.running) {
            me.app.model.reset();
            me.app.model.startRecording();
            me.startCountdown();
            Notify.start();
            me.showFlash(:start, 1500);
        } else {
            // Stop (like the stock apps): pause the activity (timer freezes,
            // logging stops), vibrate + red ring/square for ~2s, then open the
            // Resume / Save / Exit menu.
            me.app.model.pauseRecording();
            me.stopCountdown();
            Notify.stop();
            me.afterFlashMenu = true;
            me.showFlash(:stop, 2000);
        }
    }

    // Screen-4 countdown lifecycle, driven by the global activity start/stop.
    // A fresh start resets to 60; pause freezes the value so resume continues
    // from where it left off.
    function startCountdown() {
        me.countdownSecs = 60;
        me.countdownRunning = true;
    }

    function stopCountdown() {
        me.countdownRunning = false;   // keep countdownSecs so resume can continue
    }

    function resumeCountdown() {
        me.countdownRunning = true;    // continue from the frozen value
    }

    // Save/Discard: back to the initial state (60, stopped).
    function resetCountdown() {
        me.countdownSecs = 60;
        me.countdownRunning = false;
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
        } else if (me.screenIndex == 2) {
            me.drawScreen3(dc);
        } else {
            me.drawScreen4(dc);
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
        // Hero: 5-second rolling average (not instantaneous)
        var avg5s = me.app.model.avgPositiveSecs(5);
        var frozen = false;
        var displayV = avg5s;
        if (displayV == null) {
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
        me.drawTopSogTwa(dc);
        // Trend: left = avg5s vs avgSecs, right = avgSecs vs avgMins
        me.drawColsTrend(dc, avgSecsText, avgMinsText,
                         me.trendOf(avg5s, avgSecs), me.trendOf(avgSecs, avgMins));
    }

    function drawScreen2(dc) {
        // Hero: 5-second rolling average (not instantaneous)
        var avg5s = me.app.model.avgNegativeSecs(5);
        var frozen = false;
        var displayV = avg5s;
        if (displayV == null) {
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
        me.drawTopSogTwa(dc);
        // Trend: left = avg5s vs avgSecs, right = avgSecs vs avgMins
        me.drawColsTrend(dc, negSecsText, negMinsText,
                         me.trendOf(avg5s, negSecs), me.trendOf(negSecs, negMins));
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
        me.drawColsPlain(dc, avgText, timeText);
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
        dc.drawLine(midX, h * 46 / 100, midX, h * 86 / 100);
        dc.drawLine(w * 12 / 100, h * 86 / 100, w * 88 / 100, h * 86 / 100);

        dc.drawText(leftX, h * 48 / 100, Graphics.FONT_XTINY, colT1, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(rightX, h * 48 / 100, Graphics.FONT_XTINY, colT2, Graphics.TEXT_JUSTIFY_CENTER);
        // Column values are drawn per-screen: drawColsPlain (HR) or
        // drawColsTrend (VMG screens, small value + better/worse colour square).

        // Small footer (centre-bottom)
        if (footerText != null && !footerText.equals("")) {
            dc.drawText(midX, h * 89 / 100, Graphics.FONT_TINY, footerText, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // True Wind Angle: angle between the course (COG) and the wind direction
    // (TWD), normalised to (-180, 180]. Negative = heading is to PORT of the
    // TWD. |TWA| 0 = head to wind, 180 = dead downwind. Note VMG = SOG*cos(TWA),
    // so |TWA| < 90 is upwind (screen 1) and > 90 downwind (screen 2).
    function twaOf(cogDeg, twdDeg) {
        if (cogDeg == null) { return null; }
        var a = cogDeg.toNumber() - twdDeg;
        a = a % 360;
        if (a < 0) { a += 360; }
        if (a > 180) { a -= 360; }
        return a;
    }

    // Current SOG (left) and TWA (right) in the top band, above the upper line —
    // where the reference app shows the time. VMG screens only.
    function drawTopSogTwa(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var lx = w * 21 / 100;
        var rx = w * 79 / 100;

        var sogText = (me.lastSog == null) ? "--" : me.lastSog.format("%.1f");
        var twa = me.twaOf(me.lastCog, me.app.twd);
        var twaText = (twa == null) ? "--" : twa.format("%d") + "°";

        dc.drawText(lx, h * 28 / 100, Graphics.FONT_XTINY, "SOG", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(lx, h * 35 / 100, Graphics.FONT_TINY, sogText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(rx, h * 28 / 100, Graphics.FONT_XTINY, "TWA", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(rx, h * 35 / 100, Graphics.FONT_TINY, twaText, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Three-state trend with a percentage dead zone, so normal steady-state
    // sailing reads as "neutral" rather than flickering up/down. Compared by
    // magnitude (so "better" works both upwind and downwind):
    //   :up      shorter window beats the reference by > TREND_DEADBAND
    //   :down    shorter window is below the reference by > TREND_DEADBAND
    //   :neutral within +/- TREND_DEADBAND of the reference (steady)
    //   :none    missing data on either side
    // The dead zone is a percentage of the reference, so it self-scales with
    // conditions (wider band in breeze, tighter in light air).
    const TREND_DEADBAND = 0.03;   // +/- 3%
    function trendOf(cur, avg) {
        if (cur == null || avg == null) { return :none; }
        var c = cur.abs();
        var a = avg.abs();
        if (c >= a * (1.0 + TREND_DEADBAND)) { return :up; }
        if (c <= a * (1.0 - TREND_DEADBAND)) { return :down; }
        return :neutral;
    }

    // HR screen: plain large column values, no trend square.
    function drawColsPlain(dc, v1, v2) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.drawText(w * 26 / 100, h * 56 / 100, Graphics.FONT_NUMBER_MEDIUM, v1, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w * 74 / 100, h * 56 / 100, Graphics.FONT_NUMBER_MEDIUM, v2, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // VMG screens: small column value + a green/red square (live vs this average).
    function drawColsTrend(dc, v1, v2, t1, t2) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        me.drawColTrend(dc, w * 26 / 100, h, v1, t1);
        me.drawColTrend(dc, w * 74 / 100, h, v2, t2);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);   // restore default
    }

    function drawColTrend(dc, cx, h, text, trend) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.drawText(cx, h * 56 / 100, Graphics.FONT_TINY, text, Graphics.TEXT_JUSTIFY_CENTER);
        if (trend == :none) { return; }
        // Big triangle: colour + direction. Steady (:neutral) and rising (:up)
        // both show a green up triangle — "steady = good, keep doing this".
        // Only a genuine drop (:down) shows the red down triangle.
        var aw = h * 20 / 100;          // arrow width
        var top = h * 66 / 100;
        var bot = h * 84 / 100;
        if (trend == :down) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_WHITE);
            dc.fillPolygon([[cx - aw / 2, top], [cx + aw / 2, top], [cx, bot]]);
        } else {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_WHITE);
            dc.fillPolygon([[cx, top], [cx - aw / 2, bot], [cx + aw / 2, bot]]);
        }
    }

    function drawScreen4(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        // White background, black digits — same inverted theme as the other
        // screens.
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);

        var bandBottom = h * 86 / 100;             // leave room for the status line

        if (me.countdownSecs < 10) {
            // Last 10 seconds: a single, larger, BOLD digit, centred.
            var dh = bandBottom - 8;               // nearly the full band height
            var dw = dh * 10 / 18;
            var x0 = (w - dw) / 2;
            var y0 = (bandBottom - dh) / 2;
            if (y0 < 2) { y0 = 2; }
            var t  = dw * 26 / 100;                // bold (vs ~17% normal)
            me.drawSevenSeg(dc, x0, y0, dw, dh, me.countdownSecs, t);
        } else {
            // Two 7-seg digits, large but with a little margin: ~82% of the
            // width and the band above the status line.
            var dgap = w * 4 / 100;                // gap between the two digits
            var dw   = (w * 82 / 100 - dgap) / 2;  // single digit width
            var dh   = dw * 18 / 10;               // single digit height (~1.8:1)
            var x0   = (w - (2 * dw + dgap)) / 2;
            var y0   = (bandBottom - dh) / 2;
            if (y0 < 2) { y0 = 2; }
            var t    = dw * 17 / 100;              // normal thickness
            me.drawSevenSeg(dc, x0,             y0, dw, dh, me.countdownSecs / 10, t);
            me.drawSevenSeg(dc, x0 + dw + dgap, y0, dw, dh, me.countdownSecs % 10, t);
        }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        var statusText = me.countdownRunning ? "RUNNING" : "PRESS START";
        dc.drawText(cx, h * 91 / 100, Graphics.FONT_XTINY, statusText, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // 7-segment digit renderer using fillRectangle.
    // Segments: a=top, b=top-right, c=bottom-right, d=bottom,
    //           e=bottom-left, f=top-left, g=middle
    function drawSevenSeg(dc, x0, y0, dw, dh, digit, t) {
        if (t < 4) { t = 4; }   // caller sets thickness (bold for the last 10 s)
        var g  = 3;       // gap around each segment end
        var hh = dh / 2;  // half height (where middle segment sits)

        // 70 integers: 7 segment flags per digit for 0-9
        var segs = [
            1,1,1,1,1,1,0,  // 0
            0,1,1,0,0,0,0,  // 1
            1,1,0,1,1,0,1,  // 2
            1,1,1,1,0,0,1,  // 3
            0,1,1,0,0,1,1,  // 4
            1,0,1,1,0,1,1,  // 5
            1,0,1,1,1,1,1,  // 6
            1,1,1,0,0,0,0,  // 7
            1,1,1,1,1,1,1,  // 8
            1,1,1,1,0,1,1,  // 9
        ];
        var i = digit * 7;
        if (segs[i+0] != 0) { dc.fillRectangle(x0 + t+g,      y0,            dw - 2*(t+g), t); }   // a top
        if (segs[i+1] != 0) { dc.fillRectangle(x0 + dw-t,     y0 + t+g,      t, hh - t - 2*g); }   // b top-right
        if (segs[i+2] != 0) { dc.fillRectangle(x0 + dw-t,     y0 + hh+g,     t, hh - t - 2*g); }   // c bot-right
        if (segs[i+3] != 0) { dc.fillRectangle(x0 + t+g,      y0 + dh-t,     dw - 2*(t+g), t); }   // d bottom
        if (segs[i+4] != 0) { dc.fillRectangle(x0,            y0 + hh+g,     t, hh - t - 2*g); }   // e bot-left
        if (segs[i+5] != 0) { dc.fillRectangle(x0,            y0 + t+g,      t, hh - t - 2*g); }   // f top-left
        if (segs[i+6] != 0) { dc.fillRectangle(x0 + t+g,      y0 + hh - t/2, dw - 2*(t+g), t); }   // g middle
    }
}
