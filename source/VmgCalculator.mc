using Toybox.Math as Math;

class VmgCalculator {
    // Compute VMG (knots) from sog (m/s), cog (deg), twd (deg).
    static function computeVmg(sog_ms, cog_deg, twd_deg) {
        if (sog_ms == null || cog_deg == null || twd_deg == null) { return null; }
        var sog_kn = sog_ms * 1.9438;
        var angle_deg = cog_deg - twd_deg;
        // normalize to (-180, 180]
        while (angle_deg > 180) { angle_deg -= 360; }
        while (angle_deg <= -180) { angle_deg += 360; }
        var angle_rad = angle_deg * Math.PI / 180.0;
        return sog_kn * Math.cos(angle_rad);
    }
}
