using Toybox.Attention as Attention;
using Toybox.System as System;

// Start/stop audible + haptic feedback. Guarded for devices without a tone
// (the fenix3 HR vibrates but has no beeper) and for the user's sound/vibe
// settings, and wrapped in try/catch so a missing symbol can never crash.
module Notify {
    function start() { play(true); }
    function stop()  { play(false); }

    function play(isStart) {
        var ds = null;
        try { ds = System.getDeviceSettings(); } catch (e) {}

        if ((Attention has :playTone) && (ds == null || ds.tonesOn)) {
            try {
                Attention.playTone(isStart ? Attention.TONE_START : Attention.TONE_STOP);
            } catch (e) {}
        }
        if ((Attention has :vibrate) && (ds == null || ds.vibrateOn)) {
            try {
                Attention.vibrate([new Attention.VibeProfile(75, 400)]);
            } catch (e) {}
        }
    }
}
