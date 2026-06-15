// Fixed-capacity ring buffer of {ts, value} samples.
// Timestamps (ts) are integer epoch seconds (Time.now().value()).
class RingBuffer {
    var buf;
    var capacity;

    function initialize(cap) {
        me.buf = [];
        me.capacity = Util.max(1, (cap != null) ? cap : 1);
    }

    function add(ts, value) {
        me.buf.add({:ts => ts, :v => value});
        while (me.buf.size() > me.capacity) {
            me.removeOldest();
        }
    }

    function removeOldest() {
        if (me.buf.size() > 0) { me.buf.remove(me.buf[0]); }
    }

    function pruneOlderThan(cutoff) {
        while (me.buf.size() > 0 && me.buf[0][:ts] < cutoff) {
            me.buf.remove(me.buf[0]);
        }
    }

    // Average of values whose ts is within windowSecs of now.
    function getAvgWindow(windowSecs) {
        var cutoff = Time.now().value() - windowSecs;
        var sum = 0.0;
        var cnt = 0;
        for (var i = me.buf.size() - 1; i >= 0; i -= 1) {
            var e = me.buf[i];
            if (e[:ts] >= cutoff) {
                sum += e[:v];
                cnt += 1;
            } else {
                break;
            }
        }
        return (cnt == 0) ? null : (sum / cnt);
    }

    function size() {
        return me.buf.size();
    }

    function clear() {
        me.buf = [];
    }

    function setCapacity(c) {
        me.capacity = Util.max(1, c);
        while (me.buf.size() > me.capacity) { me.removeOldest(); }
    }
}
