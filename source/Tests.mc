using Toybox.Test as Test;
using Toybox.System as System;
using Toybox.Time as Time;

// Minimal stand-in for SailVMGApp exposing just what SailVMGView.windShiftTrend
// reads (me.app.model, me.app.avgLastSeconds). (:test)-gated like the test
// functions so it never enters non-test builds.
(:test)
class FakeNavApp {
    var model;
    var avgLastSeconds;
    function initialize(m, secs) {
        me.model = m;
        me.avgLastSeconds = secs;
    }
}

// Exercises the exact path that crashed on START
// (handleStart -> DataModel.startRecording). Before the fix this threw
// "Symbol Not Found: SPORT_SAILING". If it returns without throwing, it passes.
(:test)
function testStartRecordingNoCrash(logger) {
    var model = new DataModel({:avgLastSeconds => 5, :avgLastMinutes => 1});
    model.reset();
    model.startRecording();                       // <-- former crash site
    model.addSample(1000, 3.5, 45, 120, 0.5, 5.0, 40);     // positive VMG sample
    model.addSample(1001, -2.0, 45, 121, 0.5, 4.0, 140);   // negative VMG sample
    model.saveRecording();                        // close the session cleanly
    logger.debug("startRecording path completed without crashing");
    return true;
}

// Pause must stop logging and freeze the timer; resume continues both.
(:test)
function testPauseStopsLogging(logger) {
    var model = new DataModel({:avgLastSeconds => 5, :avgLastMinutes => 1});
    model.reset();
    model.addSample(1000, 3.0, 45, 120, 0.5, 5.0, 40);
    Test.assertEqualMessage(model.positiveCount, 1, "logs while running");

    model.pauseRecording();
    Test.assertEqualMessage(model.running, false, "paused -> running=false");
    // Timer frozen: two reads while paused are equal.
    Test.assertEqualMessage(model.elapsedSeconds(), model.elapsedSeconds(), "timer frozen when paused");
    model.addSample(1001, 9.0, 45, 121, 0.5, 5.0, 40);
    Test.assertEqualMessage(model.positiveCount, 1, "no logging while paused");

    model.resumeRecording();
    Test.assertEqualMessage(model.running, true, "resumed -> running=true");
    model.addSample(1002, 4.0, 45, 122, 0.5, 5.0, 40);
    Test.assertEqualMessage(model.positiveCount, 2, "logging resumes");
    return true;
}

// Save (and discard) must clear the timer and stats back to zero.
(:test)
function testSaveResetsTimer(logger) {
    var model = new DataModel({:avgLastSeconds => 5, :avgLastMinutes => 1});
    model.reset();
    model.addSample(1000, 3.0, 45, 120, 0.5, 5.0, 40);
    Test.assertEqualMessage(model.positiveCount, 1, "logged a sample");
    model.pauseRecording();
    model.saveRecording();
    Test.assertEqualMessage(model.elapsedSeconds(), 0, "timer is 0 after save");
    Test.assertEqualMessage(model.positiveCount, 0, "stats cleared after save");
    Test.assertEqualMessage(model.running, false, "not running after save");
    return true;
}

// Start/stop feedback must never crash (guarded for no-tone devices).
(:test)
function testNotifyNoCrash(logger) {
    Notify.start();
    Notify.stop();
    return true;
}

// Circular RingBuffer: capacity bound, windowed average, and resize keep newest.
(:test)
function testRingBuffer(logger) {
    var now = Time.now().value();
    var rb = new RingBuffer(3);
    rb.add(now - 40, 1.0);
    rb.add(now - 30, 2.0);
    rb.add(now - 20, 3.0);
    rb.add(now - 10, 4.0);
    rb.add(now,      5.0);
    Test.assertEqualMessage(rb.size(), 3, "capacity bounds size to 3");
    // newest 3 kept = vals 3,4,5
    Test.assertEqualMessage(rb.getAvgWindow(100), 4.0, "avg of last 3 = 4.0");
    // 15s window -> entries at now and now-10 only = 5,4
    Test.assertEqualMessage(rb.getAvgWindow(15), 4.5, "15s window avg = 4.5");
    rb.setCapacity(2);
    Test.assertEqualMessage(rb.size(), 2, "resize keeps newest 2");
    Test.assertEqualMessage(rb.getAvgWindow(100), 4.5, "after resize avg = 4.5");
    return true;
}

// Trend logic: three states with a +/-3% dead zone (by magnitude), so steady
// sailing reads :neutral and only genuine moves read :up / :down.
(:test)
function testTrend(logger) {
    var v = new SailVMGView({:app => null});
    // Clearly above/below the band.
    Test.assertEqualMessage(v.trendOf(5.0, 4.0), :up, "upwind 5>>4 -> up");
    Test.assertEqualMessage(v.trendOf(3.0, 4.0), :down, "upwind 3<<4 -> down");
    Test.assertEqualMessage(v.trendOf(-5.0, -4.0), :up, "downwind |5|>>|4| -> up");
    Test.assertEqualMessage(v.trendOf(-3.0, -4.0), :down, "downwind |3|<<|4| -> down");
    // Inside the +/-3% dead zone -> neutral (the steady-state baseline).
    Test.assertEqualMessage(v.trendOf(4.0, 4.0), :neutral, "equal -> neutral");
    Test.assertEqualMessage(v.trendOf(4.1, 4.0), :neutral, "+2.5% -> neutral");
    Test.assertEqualMessage(v.trendOf(3.9, 4.0), :neutral, "-2.5% -> neutral");
    // Just past the band edges -> up / down.
    Test.assertEqualMessage(v.trendOf(4.2, 4.0), :up, "+5% -> up");
    Test.assertEqualMessage(v.trendOf(3.8, 4.0), :down, "-5% -> down");
    Test.assertEqualMessage(v.trendOf(null, 4.0), :none, "no shorter -> none");
    Test.assertEqualMessage(v.trendOf(5.0, null), :none, "no reference -> none");
    return true;
}

// TWA: COG relative to TWD, normalised to (-180, 180], negative to port.
(:test)
function testTwa(logger) {
    var v = new SailVMGView({:app => null});
    Test.assertEqualMessage(v.twaOf(0,   0),   0,    "head to wind -> 0");
    Test.assertEqualMessage(v.twaOf(45,  0),   45,   "45 to stbd of TWD -> +45");
    Test.assertEqualMessage(v.twaOf(350, 0),  -10,   "10 to port of TWD -> -10");
    Test.assertEqualMessage(v.twaOf(180, 0),   180,  "dead downwind -> 180");
    Test.assertEqualMessage(v.twaOf(190, 0),  -170,  "190 wraps to -170 (port)");
    // Wrap across the 0/360 boundary with a non-zero TWD.
    Test.assertEqualMessage(v.twaOf(10,  350),  20,  "10 vs TWD 350 -> +20");
    Test.assertEqualMessage(v.twaOf(340, 10),  -30,  "340 vs TWD 10 -> -30");
    // assertEqualMessage can't compare null (it invokes equals()), so test the
    // predicate instead.
    Test.assertEqualMessage(v.twaOf(null, 0) == null, true, "no COG -> null");
    return true;
}

// Wind-shift triangle above TWA: only claims a shift when SOG stayed inside
// its dead zone; the direction that counts as "favourable" flips per screen.
(:test)
function testWindShiftTrend(logger) {
    var now = Time.now().value();

    // 30 s steady at SOG 5.0 / TWA 45 deg, then the last 5 s settle at TWA 35
    // (a lift) with SOG unchanged.
    var model = new DataModel({:avgLastSeconds => 30, :avgLastMinutes => 3});
    model.reset();
    for (var i = 0; i < 25; i += 1) {
        model.addSample(now - 29 + i, 3.0, 45, 120, 0.5, 5.0, 45);
    }
    for (var i = 25; i < 30; i += 1) {
        model.addSample(now - 29 + i, 3.0, 45, 120, 0.5, 5.0, 35);
    }
    var v = new SailVMGView({:app => new FakeNavApp(model, 30)});
    v.screenIndex = 0;   // upwind: shrinking |TWA| is a favourable lift
    Test.assertEqualMessage(v.windShiftTrend(), :up, "steady SOG + shrinking TWA upwind -> favourable");
    v.screenIndex = 1;   // downwind: the same shrink is now unfavourable
    Test.assertEqualMessage(v.windShiftTrend(), :down, "same shift read downwind -> unfavourable");

    // SOG is deliberately ignored: the same TWA shift reads identically even
    // when SOG drops hard at the same time.
    var model2 = new DataModel({:avgLastSeconds => 30, :avgLastMinutes => 3});
    model2.reset();
    for (var i = 0; i < 25; i += 1) {
        model2.addSample(now - 29 + i, 3.0, 45, 120, 0.5, 5.0, 45);
    }
    for (var i = 25; i < 30; i += 1) {
        model2.addSample(now - 29 + i, 3.0, 45, 120, 0.5, 3.5, 35);
    }
    var v2 = new SailVMGView({:app => new FakeNavApp(model2, 30)});
    v2.screenIndex = 0;
    Test.assertEqualMessage(v2.windShiftTrend(), :up, "SOG ignored: same lift reading despite SOG drop");

    // Dead zone must be ABSOLUTE degrees, not a percentage. A 2 deg drift the
    // unfavourable way sits inside the 5 deg band -> steady (green). Under the
    // old +/-3% rule the band at ~45 deg was only 1.4 deg, so this same input
    // would have wrongly reported a header (red).
    var model3 = new DataModel({:avgLastSeconds => 30, :avgLastMinutes => 3});
    model3.reset();
    for (var i = 0; i < 25; i += 1) {
        model3.addSample(now - 29 + i, 3.0, 45, 120, 0.5, 5.0, 45);
    }
    for (var i = 25; i < 30; i += 1) {
        model3.addSample(now - 29 + i, 3.0, 45, 120, 0.5, 5.0, 47);
    }
    var v3 = new SailVMGView({:app => new FakeNavApp(model3, 30)});
    v3.screenIndex = 0;
    Test.assertEqualMessage(v3.windShiftTrend(), :up, "2 deg drift is inside the 5 deg band -> steady");

    // A user-set 5 s "AVG Last Seconds" must not make the reference window equal
    // the 5 s window (which would compare it against itself and always read
    // steady). The reference is clamped to SHIFT_REF_MIN_SECS, so a real shift
    // is still detected with that setting.
    var model4 = new DataModel({:avgLastSeconds => 5, :avgLastMinutes => 3});
    model4.reset();
    for (var i = 0; i < 25; i += 1) {
        model4.addSample(now - 29 + i, 3.0, 45, 120, 0.5, 5.0, 45);
    }
    for (var i = 25; i < 30; i += 1) {
        model4.addSample(now - 29 + i, 3.0, 45, 120, 0.5, 5.0, 35);
    }
    var v4 = new SailVMGView({:app => new FakeNavApp(model4, 5)});
    v4.screenIndex = 0;
    Test.assertEqualMessage(v4.windShiftTrend(), :up, "5 s setting still detects a real lift");
    return true;
}

// VMG math: sog 5 m/s, heading == TWD -> angle 0 -> vmg = 5 * 1.9438 kn.
(:test)
function testVmgCalc(logger) {
    var v = VmgCalculator.computeVmg(5.0, 45, 45);
    Test.assert(v != null);
    Test.assertEqualMessage(v > 9.7 && v < 9.8, true, "expected ~9.72 kn, got " + v);

    // Beam reach (90 deg off) -> cos(90) ~ 0 -> vmg ~ 0.
    var beam = VmgCalculator.computeVmg(5.0, 135, 45);
    Test.assertEqualMessage(beam.abs() < 0.01, true, "expected ~0 kn, got " + beam);
    return true;
}

// Nearest-compass-label wrap fix (the bug found during verification).
(:test)
function testNearestSnapWrap(logger) {
    var view = new SettingsTWDView(null, 0);
    Test.assertEqualMessage(view.findNearestSnap(350), "N",  "350 -> N");
    Test.assertEqualMessage(view.findNearestSnap(359), "N",  "359 -> N");
    Test.assertEqualMessage(view.findNearestSnap(338), "N",  "338 -> N");
    Test.assertEqualMessage(view.findNearestSnap(337), "NW", "337 -> NW");
    Test.assertEqualMessage(view.findNearestSnap(45),  "NE", "45 -> NE");
    Test.assertEqualMessage(view.findNearestSnap(180), "S",  "180 -> S");
    return true;
}
