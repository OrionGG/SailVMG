// Small numeric helpers. Toybox.Math has no max/min (and no abs;
// abs() is a method on the numeric types), so we provide our own.
module Util {
    function max(a, b) {
        return (a > b) ? a : b;
    }

    function min(a, b) {
        return (a < b) ? a : b;
    }

    // Format a whole number of seconds as M:SS, or H:MM:SS once past an hour.
    function fmtDuration(secs) {
        var h = secs / 3600;
        var m = (secs % 3600) / 60;
        var s = secs % 60;
        if (h > 0) {
            return h.format("%d") + ":" + m.format("%02d") + ":" + s.format("%02d");
        }
        return m.format("%d") + ":" + s.format("%02d");
    }
}
