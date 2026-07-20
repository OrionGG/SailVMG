using Toybox.Time as Time;
using Toybox.ActivityRecording as ActivityRecording;
using Toybox.FitContributor as FitContributor;
using Toybox.System as System;
using Toybox.Math as Math;

class DataModel {
    var startTime = null;          // start of the current running segment
    var accumulatedSeconds = 0;    // elapsed time banked from prior segments
    var running = false;           // currently recording (false while paused)

    var positiveSum = 0.0;
    var positiveCount = 0;
    var negativeSum = 0.0;
    var negativeCount = 0;
    var hrSum = 0;
    var hrCount = 0;

    var posBuffer = null;
    var negBuffer = null;

    // Wind-shift detection: rolling SOG (kn) and |TWA| (deg). |TWA| rather than
    // signed TWA so there is no wrap discontinuity at +/-180 (dead downwind) and
    // so a tack/gybe doesn't register as a shift.
    var sogBuffer = null;
    var twaBuffer = null;

    var lastPositive = null;
    var lastNegative = null;

    var session = null;
    var vmgField = null;
    var twdField = null;

    var secondsWindow = 30;
    var minutesWindow = 3;

    // params: {:avgLastSeconds => Number, :avgLastMinutes => Number}
    function initialize(params) {
        if (params == null) { params = {}; }
        if (params[:avgLastSeconds] != null) {
            me.secondsWindow = params[:avgLastSeconds];
        } else {
            me.secondsWindow = 30;
        }
        if (params[:avgLastMinutes] != null) {
            me.minutesWindow = params[:avgLastMinutes];
        } else {
            me.minutesWindow = 3;
        }

        var capacity = me.bufferCapacity();
        me.posBuffer = new RingBuffer(capacity);
        me.negBuffer = new RingBuffer(capacity);
        var navCap = me.navCapacity();
        me.sogBuffer = new RingBuffer(navCap);
        me.twaBuffer = new RingBuffer(navCap);
    }

    function bufferCapacity() {
        var capSeconds = Util.max(1, me.secondsWindow);
        var capMinutesSec = Util.max(1, me.minutesWindow * 60);
        // Cap entries so the preallocated buffers stay well within device RAM.
        return Util.min(Util.max(capSeconds, capMinutesSec), 900);
    }

    // Shift detection only compares the 5 s window against the seconds window,
    // so these buffers never need the (much larger) minutes capacity.
    function navCapacity() {
        return Util.min(Util.max(5, me.secondsWindow), 300);
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
        me.zeroStats();   // back to a clean slate (timer 0:00, averages --)
    }

    function discardRecording() {
        if (me.session != null) {
            me.session.discard();
            me.clearSession();
        }
        me.running = false;
        me.zeroStats();
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

    // Zero all accumulators (timer, sums, buffers). Leaves running unchanged.
    function zeroStats() {
        me.startTime = null;
        me.accumulatedSeconds = 0;
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

    function reset() {
        me.zeroStats();
        me.startTime = Time.now().value();
        me.running = true;
    }

    // Pause: bank elapsed time and stop logging to the FIT.
    function pauseRecording() {
        if (me.running) {
            if (me.startTime != null) {
                me.accumulatedSeconds += Time.now().value() - me.startTime;
            }
            me.running = false;
            if (me.session != null) {
                try { me.session.stop(); } catch (e) { }
            }
        }
    }

    // Resume: restart the segment clock and the FIT recording.
    function resumeRecording() {
        me.startTime = Time.now().value();
        me.running = true;
        if (me.session != null) {
            try { me.session.start(); } catch (e) { }
        }
    }

    // Add a sample once per second. ts is integer epoch seconds.
    // No-op while paused so the activity stops accumulating data.
    function addSample(ts, vmg, twd, hr, minAbs) {
        if (!me.running) { return; }

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
        // No prune needed: the ring buffers self-bound to their capacity.
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

    // Elapsed activity time in seconds (banked segments + current running one).
    // Frozen while paused.
    function elapsedSeconds() {
        var total = me.accumulatedSeconds;
        if (me.running && me.startTime != null) {
            total += Time.now().value() - me.startTime;
        }
        return total;
    }

    function getLastPositive() { return me.lastPositive; }
    function getLastNegative() { return me.lastNegative; }
}
