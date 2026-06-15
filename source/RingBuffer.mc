using Toybox.Time as Time;

// Fixed-capacity circular buffer of (ts, value) samples for rolling averages.
// Two preallocated primitive arrays (no per-sample Dictionary allocation, no
// shifting on prune) keep memory small and avoid GC churn. Timestamps are
// integer epoch seconds; the ring self-bounds to `capacity`, so no separate
// time-based prune is needed.
class RingBuffer {
    var ts;         // epoch seconds
    var vals;       // values
    var capacity;
    var head;       // index of the oldest entry
    var count;      // number of valid entries

    function initialize(cap) {
        me.capacity = Util.max(1, (cap != null) ? cap : 1);
        me.ts = new [me.capacity];
        me.vals = new [me.capacity];
        me.head = 0;
        me.count = 0;
    }

    function add(t, value) {
        var idx;
        if (me.count < me.capacity) {
            idx = (me.head + me.count) % me.capacity;
            me.count += 1;
        } else {
            idx = me.head;                          // overwrite oldest
            me.head = (me.head + 1) % me.capacity;
        }
        me.ts[idx] = t;
        me.vals[idx] = value;
    }

    // Average of values whose ts is within windowSecs of now (newest-first,
    // stops at the first entry outside the window since entries are ordered).
    function getAvgWindow(windowSecs) {
        if (me.count == 0) { return null; }
        var cutoff = Time.now().value() - windowSecs;
        var sum = 0.0;
        var cnt = 0;
        for (var i = 0; i < me.count; i += 1) {
            var idx = (me.head + me.count - 1 - i + me.capacity) % me.capacity;
            if (me.ts[idx] >= cutoff) {
                sum += me.vals[idx];
                cnt += 1;
            } else {
                break;
            }
        }
        return (cnt == 0) ? null : (sum / cnt);
    }

    function size() {
        return me.count;
    }

    function clear() {
        me.head = 0;
        me.count = 0;
    }

    function setCapacity(c) {
        var nc = Util.max(1, c);
        if (nc == me.capacity) { return; }
        var keep = (me.count < nc) ? me.count : nc;   // keep the newest entries
        var nts = new [nc];
        var nvals = new [nc];
        for (var i = 0; i < keep; i += 1) {
            var src = (me.head + me.count - keep + i + me.capacity) % me.capacity;
            nts[i] = me.ts[src];
            nvals[i] = me.vals[src];
        }
        me.ts = nts;
        me.vals = nvals;
        me.capacity = nc;
        me.head = 0;
        me.count = keep;
    }
}
