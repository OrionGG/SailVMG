// Build-time toggle for SIMULATOR-ONLY fake data (see README, "Simulator test
// data flag"). The value is chosen by which annotation the build excludes, not
// by editing any committed source:
//
//   monkey.jungle      (committed) excludes :simdata      -> enabled() == false
//   monkey.sim.jungle  (gitignored) excludes :notsimdata  -> enabled() == true
//
// So every committed / release / fresh-checkout build is false, and the "true"
// only exists when the local, gitignored sim jungle is present. Exactly one
// enabled() survives each build (the other annotation is excluded), so there is
// no duplicate-symbol clash.
module SimConfig {
    (:simdata)    function enabled() { return true; }
    (:notsimdata) function enabled() { return false; }
}
