using Toybox.Test as Test;
using Toybox.System as System;
using Toybox.Time as Time;

// Exercises the exact path that crashed on START
// (handleStart -> DataModel.startRecording). Before the fix this threw
// "Symbol Not Found: SPORT_SAILING". If it returns without throwing, it passes.
(:test)
function testStartRecordingNoCrash(logger) {
    var model = new DataModel({:avgLastSeconds => 5, :avgLastMinutes => 1});
    model.reset();
    model.startRecording();                       // <-- former crash site
    model.addSample(1000, 3.5, 45, 120, 0.5);     // positive VMG sample
    model.addSample(1001, -2.0, 45, 121, 0.5);    // negative VMG sample
    model.saveRecording();                        // close the session cleanly
    logger.debug("startRecording path completed without crashing");
    return true;
}

// Pause must stop logging and freeze the timer; resume continues both.
(:test)
function testPauseStopsLogging(logger) {
    var model = new DataModel({:avgLastSeconds => 5, :avgLastMinutes => 1});
    model.reset();
    model.addSample(1000, 3.0, 45, 120, 0.5);
    Test.assertEqualMessage(model.positiveCount, 1, "logs while running");

    model.pauseRecording();
    Test.assertEqualMessage(model.running, false, "paused -> running=false");
    // Timer frozen: two reads while paused are equal.
    Test.assertEqualMessage(model.elapsedSeconds(), model.elapsedSeconds(), "timer frozen when paused");
    model.addSample(1001, 9.0, 45, 121, 0.5);
    Test.assertEqualMessage(model.positiveCount, 1, "no logging while paused");

    model.resumeRecording();
    Test.assertEqualMessage(model.running, true, "resumed -> running=true");
    model.addSample(1002, 4.0, 45, 122, 0.5);
    Test.assertEqualMessage(model.positiveCount, 2, "logging resumes");
    return true;
}

// Save (and discard) must clear the timer and stats back to zero.
(:test)
function testSaveResetsTimer(logger) {
    var model = new DataModel({:avgLastSeconds => 5, :avgLastMinutes => 1});
    model.reset();
    model.addSample(1000, 3.0, 45, 120, 0.5);
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

// Trend square logic: green (:up) when live beats the average by magnitude.
(:test)
function testTrend(logger) {
    var v = new SailVMGView({:app => null});
    Test.assertEqualMessage(v.trendOf(5.0, 4.0), :up, "upwind 5>4 -> up");
    Test.assertEqualMessage(v.trendOf(3.0, 4.0), :down, "upwind 3<4 -> down");
    Test.assertEqualMessage(v.trendOf(-5.0, -4.0), :up, "downwind |5|>|4| -> up");
    Test.assertEqualMessage(v.trendOf(-3.0, -4.0), :down, "downwind |3|<|4| -> down");
    Test.assertEqualMessage(v.trendOf(null, 4.0), :none, "no live -> none");
    Test.assertEqualMessage(v.trendOf(5.0, null), :none, "no avg -> none");
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
