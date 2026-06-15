// Small numeric helpers. Toybox.Math has no max/min (and no abs;
// abs() is a method on the numeric types), so we provide our own.
module Util {
    function max(a, b) {
        return (a > b) ? a : b;
    }

    function min(a, b) {
        return (a < b) ? a : b;
    }
}
