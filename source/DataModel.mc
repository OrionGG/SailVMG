using Toybox.Time as Time;
using Toybox.ActivityRecording as ActivityRecording;
using Toybox.FitContributor as FitContributor;
using Toybox.System as System;
using Toybox.Math as Math;

class DataModel {
    var startTime = null;
    var running = false;

    var positiveSum = 0.0;
    var positiveCount = 0;
    var negativeSum = 0.0;
    var negativeCount = 0;
    var hrSum = 0;
    var hrCount = 0;

    var posBuffer = null;
    var negBuffer = null;

    var lastPositive = null;
    var lastNegative = null;

    var session = null;
    var vmgField = null;
    var twdField = null;

    var secondsWindow = 5;
    var minutesWindow = 1;

    // params: {:avgLastSeconds => Number, :avgLastMinutes => Number}
    function initialize(params) {
        if (params == null) { params = {}; }
        if (params[:avgLastSeconds] != null) {
            me.secondsWindow = params[:avgLastSeconds];
        } else {
            me.secondsWindow = 5;
        }
        if (params[:avgLastMinutes] != null) {
            me.minutesWindow = params[:avgLastMinutes];
        } else {
            me.minutesWindow = 1;
        }

        var capacity = me.bufferCapacity();
        me.posBuffer = new RingBuffer(capacity);
        me.negBuffer = new RingBuffer(capacity);
    }

    function bufferCapacity() {
        var capSeconds = Util.max(1, me.secondsWindow);
        var capMinutesSec = Util.max(1, me.minutesWindow * 60);
        return Util.min(Util.max(capSeconds, capMinutesSec), 3600);
    }

    // Start (or restart) a recording session and register FIT fields.
    function startRecording() {
        // SPORT_GENERIC exists since CIQ 1.0.0; SPORT_SAILING is not present on
        // fenix3_hr firmware and would throw Symbol Not Found at runtime.
        if (me.session == null) {
            try {
                me.session = ActivityRecording.createSession({
                    :name => "SailVMG",
                    :sport => ActivityRecording.SPORT_GENERIC
                });
            } catch (e) {
                System.println("createSession failed: " + e.getErrorMessage());
                me.session = null;
            }
        }
        if (me.session == null) { return; }

        // Custom FIT fields are best-effort; failure must not stop recording.
        if (me.vmgField == null) {
            try {
                me.vmgField = me.session.createField(
                    "vmg", 0, FitContributor.DATA_TYPE_FLOAT,
                    {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "kn"});
                me.twdField = me.session.createField(
                    "twd", 1, FitContributor.DATA_TYPE_FLOAT,
                    {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "deg"});
            } catch (e) {
                System.println("createField failed: " + e.getErrorMessage());
                me.vmgField = null;
                me.twdField = null;
            }
        }

        try {
            me.session.start();
        } catch (e) {
            System.println("session.start failed: " + e.getErrorMessage());
        }
    }

    function saveRecording() {
        if (me.session != null) {
            me.session.save();
            me.clearSession();
        }
        me.running = false;
    }

    function discardRecording() {
        if (me.session != null) {
            me.session.discard();
            me.clearSession();
        }
        me.running = false;
    }

    function clearSession() {
        me.session = null;
        me.vmgField = null;
        me.twdField = null;
    }

    function updateWindowSettings(avgSeconds, avgMinutes) {
        me.secondsWindow = avgSeconds;
        me.minutesWindow = avgMinutes;
        var capacity = me.bufferCapacity();
        if (me.posBuffer == null) {
            me.posBuffer = new RingBuffer(capacity);
            me.negBuffer = new RingBuffer(capacity);
        } else {
            me.posBuffer.setCapacity(capacity);
            me.negBuffer.setCapacity(capacity);
        }
    }

    function reset() {
        me.startTime = Time.now().value();
        me.running = true;
        me.positiveSum = 0.0;
        me.positiveCount = 0;
        me.negativeSum = 0.0;
        me.negativeCount = 0;
        me.hrSum = 0;
        me.hrCount = 0;
        if (me.posBuffer != null) { me.posBuffer.clear(); }
        if (me.negBuffer != null) { me.negBuffer.clear(); }
        me.lastPositive = null;
        me.lastNegative = null;
    }

    // Add a sample once per second. ts is integer epoch seconds.
    function addSample(ts, vmg, twd, hr, minAbs) {
        if (hr != null && hr > 0) {
            me.hrSum += hr;
            me.hrCount++;
        }

        if (vmg != null) {
            var absVmg = vmg.abs();
            if (absVmg >= minAbs) {
                if (vmg > 0) {
                    me.positiveSum += vmg;
                    me.positiveCount++;
                    if (me.posBuffer != null) { me.posBuffer.add(ts, vmg); }
                    me.lastPositive = vmg;
                } else if (vmg < 0) {
                    me.negativeSum += vmg;
                    me.negativeCount++;
                    if (me.negBuffer != null) { me.negBuffer.add(ts, vmg); }
                    me.lastNegative = vmg;
                }
            }
        }

        // Write FIT record fields (best-effort).
        if (me.vmgField != null && vmg != null) { me.vmgField.setData(vmg.toFloat()); }
        if (me.twdField != null && twd != null) { me.twdField.setData(twd.toFloat()); }

        // Prune entries beyond the max window to keep memory bounded.
        var maxWindow = Util.max(me.secondsWindow, me.minutesWindow * 60);
        var cutoff = Time.now().value() - maxWindow;
        if (me.posBuffer != null) { me.posBuffer.pruneOlderThan(cutoff); }
        if (me.negBuffer != null) { me.negBuffer.pruneOlderThan(cutoff); }
    }

    function avgPositiveSinceStart() {
        if (me.positiveCount == 0) { return null; }
        return me.positiveSum / me.positiveCount;
    }

    function avgNegativeSinceStart() {
        if (me.negativeCount == 0) { return null; }
        return me.negativeSum / me.negativeCount;
    }

    function avgHr() {
        if (me.hrCount == 0) { return null; }
        return Math.round(me.hrSum.toFloat() / me.hrCount);
    }

    // Rolling-average API.
    function avgPositiveSecs(windowSecs) {
        if (me.posBuffer == null) { return null; }
        return me.posBuffer.getAvgWindow(windowSecs);
    }

    function avgPositiveMins(windowMins) {
        if (me.posBuffer == null) { return null; }
        return me.posBuffer.getAvgWindow(windowMins * 60);
    }

    function avgNegativeSecs(windowSecs) {
        if (me.negBuffer == null) { return null; }
        return me.negBuffer.getAvgWindow(windowSecs);
    }

    function avgNegativeMins(windowMins) {
        if (me.negBuffer == null) { return null; }
        return me.negBuffer.getAvgWindow(windowMins * 60);
    }

    function getLastPositive() { return me.lastPositive; }
    function getLastNegative() { return me.lastNegative; }
}
