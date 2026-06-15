# SailVMG — Garmin fēnix 3 HR sailing app

A Connect IQ **watch‑app** that computes and displays **VMG (Velocity Made Good)** for
sailing, records a GPS activity (with `vmg`/`twd` FIT developer fields), and shows
live speed/heading and heart‑rate data.

- **Target device:** fēnix 3 HR
- **Connect IQ:** 1.4.4 (manifest `minApiLevel` 1.3.0)
- **App type:** `watch-app`

## What VMG means here

`VMG = SOG × cos(heading − TWD)` — your speed component along the wind axis, where
**TWD** is the direction the wind blows *from*.

- Sailing **toward** the wind (upwind/beating) → **positive** VMG → **Screen 1**.
- Sailing **away** from the wind (downwind/running) → **negative** VMG → **Screen 2**.
- Beam reach (≈90° to the wind) → VMG ≈ 0.

## Screens

1. **VMG** (upwind) — big VMG number; `SOG` (kts) top‑left and `COG` (deg) top‑right;
   `AVG VMG Secs` / `AVG VMG Mins` rolling averages; `TWD` footer.
2. **−VMG** (downwind) — same layout for the negative component.
3. **HR** — current heart rate; `AVG HR` and the elapsed activity `TIMER`.

Rendering: inverted (black on white), big hero value (`FONT_NUMBER_HOT`, the largest
font that renders on this device), grid split lines, and a transient green/red ring
overlay on start/stop.

## Controls (fēnix 3 HR buttons)

| Button | Action |
|---|---|
| UP / DOWN | Previous / next screen |
| START | Begin activity; press again to **Stop** |
| hold UP (MENU) | Settings |
| BACK | Exit app |

**Start** → vibrate + green ring/play, recording begins.
**Stop** (START while recording) → activity **pauses** (timer freezes, logging stops),
vibrate + red ring/square for ~2 s, then the **Resume / Save / Discard** menu.
**Resume** → vibrate + green ring, recording continues. **Discard** asks **No/Yes**.
**Save**/**Discard** finalize and reset the timer/stats to zero.

## Settings (hold UP)

`Set TWD` (compass snap menu → 1° fine adjust), `Set Min ABS VMG`,
`Set AVG Last Seconds`, `Set AVG Last Minutes`. Values persist in the Object Store
(`get/setProperty`).

## Build

Use the Connect IQ SDK tools (`monkeyc`/`monkeydo` in the SDK `bin/`). A developer key
is required (`keys/developer_key`).

```powershell
# Release build (stripped, for the watch)
monkeyc -d fenix3_hr -f monkey.jungle -o SailVMG.prg -r -w -y keys/developer_key

# Debug build (symbolicated, for the simulator)
monkeyc -d fenix3_hr -f monkey.jungle -o SailVMG.prg -g -w -y keys/developer_key
```

## Run in the simulator

```powershell
connectiq                       # launch the Connect IQ simulator
monkeydo SailVMG.prg fenix3_hr  # load the app into it
```

Note: the simulator's *Data Simulation* drives `Activity.Info` and `Sensor` (so HR
works), but **not** the GPS `Position` API the app reads — so VMG/SOG/COG stay `--`
in the sim. Verify those on the watch (or by playing back a real GPS track).

## Unit tests

```powershell
monkeyc -t -d fenix3_hr -f monkey.jungle -o SailVMG_test.prg -g -w -y keys/developer_key
monkeydo SailVMG_test.prg fenix3_hr /t
```

Tests live in `source/Tests.mc` (VMG math, nearest‑compass wrap, pause stops
logging, save resets the timer, start/stop feedback never crashes).

## Sideload to the watch

The fēnix 3 HR mounts as a USB mass‑storage drive. Copy the release build to the
device and eject:

```
copy SailVMG.prg  <GARMIN drive>\GARMIN\Apps\SailVMG.prg
```

Then launch **SailVMG** from the watch's START → app list.

## FIT recording

On start the app creates an `ActivityRecording` session (`SPORT_GENERIC`) and two
record‑level FIT developer fields, `vmg` (kn) and `twd` (deg), written once per second
while recording. The GPS track is recorded by the session, so the activity shows a map
when synced to Garmin Connect / downloaded to a PC.

## Source layout

| File | Role |
|---|---|
| `SailVMGApp.mc` | `AppBase`: loads/saves settings (Object Store), `getInitialView` |
| `SailVMGView.mc` | Data screens, 1 Hz sampling, start/stop ring overlay |
| `SailVMGDelegate.mc` | `BehaviorDelegate` button mapping |
| `DataModel.mc` | Stats, rolling averages, recording session, pause/resume, elapsed timer |
| `VmgCalculator.mc` | VMG math |
| `RingBuffer.mc` | Fixed‑capacity buffer for rolling averages |
| `Util.mc` | `max`/`min`, duration formatting |
| `Notify.mc` | Vibrate / tone (guarded for devices without a tone) |
| `PauseMenuView.mc` | Pause menu + Discard confirmation |
| `SettingsMenuView.mc` | Settings menu + value‑adjust delegate |
| `SettingsTWDView.mc` | TWD compass snap menu + fine adjust |
| `SettingsMinVmgView.mc`, `SettingsAvgSecsView.mc`, `SettingsAvgMinView.mc` | Value‑adjust screens |
| `Tests.mc` | Unit tests (compiled only with `-t`) |

## fēnix 3 HR / CIQ 1.x gotchas (learned the hard way)

These compile but misbehave at runtime if ignored:

- `Position.Info.heading` is in **radians** (convert with `Math.toDegrees`); `speed` is m/s.
- Some union‑API symbols aren't on the device: use `ActivityRecording.SPORT_GENERIC`
  (not `SPORT_SAILING`); `FONT_NUMBER_HOT` is the largest number font that renders
  (`FONT_NUMBER_THAI_HOT` is blank on the `ww` font set).
- The legacy `WatchUi.Menu` **auto‑dismisses** on selection — never `popView` inside a
  `MenuInputDelegate.onMenuItem` (that exits the app).
- No `Toybox.Storage` (use AppBase `get/setProperty`); self‑reference is `me`, not
  `this`; `Toybox.Math` has no `max`/`min`/`abs` (`abs()` is a method on numerics).
