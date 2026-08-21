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

Rendering is inverted (black on white). The headline value uses the largest number
font that renders on this device (`FONT_NUMBER_HOT`), vertically centred.

1. **VMG** (upwind) — big **5‑second rolling average VMG** (centre‑top); **SOG** (kts)
   top‑left and **TWA** (deg) top‑right, above the upper divider; two columns **AVG VMG
   Secs** (default 30 s) / **AVG VMG Mins** (default 3 min); **TWD** footer.

   **TWA** (True Wind Angle) is the course relative to the wind, normalised to
   (−180, 180]: **negative = heading is to port of the TWD**. `0` is head to wind,
   `±180` dead downwind. Since `VMG = SOG × cos(TWA)`, `|TWA| < 90` is upwind
   (Screen 1) and `> 90` downwind (Screen 2).

   Just **above the SOG label** is the **polar target SOG** for the selected TWS band —
   the upwind target on Screen 1, the downwind target on Screen 2 — so the target and
   the live SOG stack for a glance comparison (both to 2 decimals). See *Settings* for
   the band selection and the polar table.
2. **−VMG** (downwind) — same layout for the negative component (values shown with a
   leading `−`).
3. **HR** — current heart rate; **AVG HR** and the elapsed activity **TIMER**.
4. **Countdown** — a giant two‑digit 7‑segment **seconds** display on a black
   background, driven by the same START as the rest of the app. On start it counts
   `60 → 0`, then loops `59 → 0` repeatedly (i.e. `…1, 0, 59, 58…`). Green digits while
   running, white when stopped.

A `*` to the **left** of the big value means it's a *held* last value (no live 5 s
average available yet — falls back to the last known good reading). It sits on the left
because the right of that band is where the wind‑shift triangle lives, and a wide value
like `-12.34` (107 px of a 218 px screen) would otherwise push the `*` into it.

The **instantaneous** VMG is still recorded to FIT every second; only the *displayed*
hero number is the 5‑second rolling average (smoother and more actionable while sailing).

### Better/worse trend triangles (Screens 1 & 2)

Each AVG VMG column shows its value in a small font plus a large colour triangle:

- **Left column (AVG VMG Secs):** compares the **5 s avg** to the **Secs avg** (default
  30 s) — are you improving right now relative to the recent trend?
- **Right column (AVG VMG Mins):** compares the **Secs avg** to the **Mins avg**
  (default 3 min) — is the recent trend above the session‑level trend?

A **±3 % dead zone** (a percentage of the reference tier, so it self‑scales with
conditions) separates three states, of which two are drawn:

- green **▲** — **steady or rising**: the shorter window is within ±3 % of the
  reference (neutral baseline) **or** above it. Steady = good — keep doing what you're
  doing. When you're sailing well and consistently you should see green ▲ on both
  comparisons.
- red **▼** — **genuine drop**: the shorter window is more than 3 % *below* the
  reference. Red only appears when something has actually changed, so it means
  something when it does.
- **no triangle** — not enough data yet.

The dead zone scales with the value: ≈±0.05 kn around 1.8 kn in light air, ≈±0.11 kn
around 3.8 kn in breeze — no setting to touch. The comparison is by **magnitude**, so
"▲ = doing at least as well for this point of sail" holds both upwind and downwind. The
HR screen has no trend triangle.

### Wind‑shift marker (Screens 1 & 2)

A two‑layer marker up‑right of the hero number flags a likely **true‑wind shift**, using
the classic compass‑oscillation technique: with **TWD fixed** on the watch (it's set once
before sailing and doesn't track the real wind in real time), holding a steady heading
while the *actual* wind shifts changes the boat's angle relative to that fixed TWD — even
though the sailor did nothing differently. So a change in **|TWA|** flags the shift.

The two layers answer two different questions at once:

- **Circle (fill) = phase, over the minutes window** — *which side of the oscillation am
  I on right now?* Green = favourable side, red = unfavourable side, **nothing** when
  you're within the dead zone of your multi‑minute average (on your mean beat heading).
- **Triangle (on top, white‑haloed) = transition, over the seconds window** — *is it
  changing right now?* Green ▲ improving, red ▼ worsening, **nothing** when steady.

Reading combinations: a lone circle = "on this side, steady"; circle + a same‑colour
triangle = both signals agree (the white halo keeps the triangle legible); a **red
triangle on a green circle** = "good side, but it's starting to slip" — the most useful
early warning.

Both layers use **|TWA|** with an absolute **±5° dead zone** — not a percentage: ±3 % of
a 45° beat is only ±1.4°, well inside normal steering and COG noise, which would make the
marker flicker. Real oscillating shifts are 5–15°. The favourable direction flips per
screen:

- **Screen 1 (upwind):** |TWA| **shrinking** = favourable **lift**; growing = **header**.
- **Screen 2 (downwind):** mirrored — |TWA| **growing** (sailing deeper) = the lift;
  shrinking = the header.

The transition compares the 5 s window against `Set AVG Last Seconds` (floored to a
**minimum of 20 s** so a short setting can't compare the 5 s window against itself); the
phase compares it against `Set AVG Last Minutes`. Both buffers only fill **while the
activity is recording**, so the marker appears once you've been running a little.

**SOG is not consulted** — the reading is purely the angle change. That keeps it simple
and predictable, at the cost of the marker also reacting when *you* change course rather
than the wind: steering up or bearing away moves |TWA| just like a shift does. Read it
alongside the SOG number, which is right next to it. There's no separate trend marker
above SOG — "SOG went up" isn't reliably good or bad on its own (bearing away raises SOG
while it can lower VMG).

## Controls (fēnix 3 HR buttons)

| Button | Action |
|---|---|
| UP / DOWN | Previous / next screen |
| START | Begin activity; press again to **Stop** |
| hold UP (MENU) | Settings |
| BACK | Exit app **when idle**; ignored while recording (stop via START first) |

## Activity flow (like the stock apps)

- **Start** (START) → vibrate + **green ring + play ▶** (~1.5 s), recording begins.
- **Stop** (START while recording) → the activity **pauses** (TIMER freezes, data
  logging stops via `Session.stop()`), vibrate + **red ring + stop ■** (~2 s), then
  the **Resume / Save / Discard** menu.
- **Resume** → vibrate + green ring, recording continues; TIMER resumes.
- **Save** → writes the FIT activity, then resets the TIMER/stats to zero.
- **Discard** → asks **No / Yes** (defaults to No); Yes discards and resets.

## Settings (hold UP)

`Set TWD` (compass snap list → 1° fine adjust), `Set TWS`, `Set Min ABS VMG`,
`Set AVG Last Seconds` (default 30, max 300), `Set AVG Last Minutes` (default 3, max
15). The averaging windows are capped to keep memory bounded on the device. Values
persist in the Object Store (`get/setProperty`).

`Set TWS` picks the **True Wind Speed band** (UP/DOWN to change, START to save). It
drives the **polar target SOG** shown above the SOG label. The band list and the polar
targets live together in `SailVMGApp` (`twsBands`, `twsUpwindSog`, `twsDownwindSog`):

| TWS band | Upwind target (kn) | Downwind target (kn) |
|---|---|---|
| 4–8 kts | 4.11 | 4.37 |
| 8–12 kts | 4.64 | 5.49 |
| 12–15 kts | 5.08 | 7.56 |
| 15–18 kts | 4.91 | 8.71 |

## Prerequisites

- **Connect IQ SDK** — builds with a current SDK (verified on **9.2.0**); `monkeyc` /
  `monkeydo` live in the SDK `bin/`. The SDK core zip is a **direct, no‑login download**
  from `developer.garmin.com/downloads/connect-iq/sdks/` (the `sdks.json` there lists every
  version + Windows/Mac/Linux filename). It ships **no bundled JRE**, so a system Java is
  required — `monkeyc` runs on **Java 8+** (9.2.0 verified under JRE 1.8).
- **The `fenix3_hr` device package** installed via the **SDK Manager**. Device packages
  download separately from the SDK **and require a Garmin account sign‑in** — the device
  endpoints (`api.gcs.garmin.com/ciq-product-onboarding/…`) are auth‑gated (Bearer token),
  so unlike the SDK core there is no anonymous download. Without the package the build
  fails with `Invalid device id specified: 'fenix3_hr'`. It installs under
  `%APPDATA%\Garmin\ConnectIQ\Devices\fenix3_hr\` (macOS `~/Library/Application Support/…`,
  Linux `~/.Garmin/…`), where `monkeyc` from any SDK finds it. (CIQ 1.x devices are still
  available — they were not dropped.)
- **A developer key** at `keys/developer_key` (PKCS#8 DER) — see below.

Repo files the build needs, beyond `source/`:

| File / dir | Role |
|---|---|
| `manifest.xml` | app id, `entry="SailVMGApp"`, `type="watch-app"`, product `fenix3_hr`, `minApiLevel 1.3.0`, permissions, launcher icon + name refs |
| `monkey.jungle` | build config (points at `manifest.xml`, `source/`, `resources/`); excludes `:simdata` so fake data is off |
| `monkey.sim.jungle` | **gitignored, optional** — local sim build that turns fake data on (excludes `:notsimdata`) |
| `resources/strings/strings.xml` | `AppName` |
| `resources/bitmaps.xml`, `resources/images/launcher.png` | launcher icon |
| `keys/` | developer key (gitignored — never committed) |

The `id` in `manifest.xml` is a placeholder UUID; it's fine for sideloading and the
simulator, and only needs to be a real app id for Connect IQ Store submission.

## Build

Use the Connect IQ SDK tools (`monkeyc`/`monkeydo` in the SDK `bin/`). A developer key
is required at `keys/developer_key` (PKCS#8 DER). `keys/` is gitignored — never commit it.

```powershell
# Release build (stripped, ~28 KB, for the watch)
monkeyc -d fenix3_hr -f monkey.jungle -o SailVMG.prg -r -w -y keys/developer_key

# Debug build (symbolicated, ~130 KB, for the simulator)
monkeyc -d fenix3_hr -f monkey.jungle -o SailVMG-debug.prg -g -w -y keys/developer_key
```

> **Fake data can't leak to the watch:** the committed `monkey.jungle` **excludes** the
> fake‑data path (`SimConfig.enabled()` compiles to `false`), so a plain release (`-r`)
> build is always clean — nothing to remember. Fake data only turns on when you build
> with the gitignored `monkey.sim.jungle` (see *Simulator test data flag* below).

### Committed build variants

Three prebuilt binaries are committed, so a fresh checkout has all three on hand. The `-o`
output name is the only thing that differs in how each is produced:

| File | How it's built | Fake data | Use |
|---|---|---|---|
| `SailVMG.prg` | `-r` release, `monkey.jungle` | off | **Sideload this to the watch** (~28 KB) |
| `SailVMG-debug.prg` | `-g` debug, `monkey.jungle` | off | Simulator / on‑device debugging (~130 KB) |
| `SailVMG-sim.prg` | `-g` debug, `monkey.sim.jungle` | **on** | Simulator only — **never sideload** (~130 KB) |

`SailVMG-sim.prg` is the only committed binary with `SimConfig.enabled()` true; it exists
purely to demo the populated layout in the simulator (the sim never feeds the GPS
`Position` API). The watch artifact is always `SailVMG.prg` (release, fake data off).

Generate a fresh developer key (if needed):

```bash
openssl genrsa -out keys/developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in keys/developer_key.pem -out keys/developer_key -nocrypt
```

## Run in the simulator

```powershell
connectiq                       # launch the Connect IQ simulator
monkeydo SailVMG.prg fenix3_hr  # load the app into it
```

Note: the simulator's *Data Simulation* drives `Activity.Info` and `Sensor` (so HR
works), but **not** the GPS `Position` API the app reads — so VMG / SOG / TWA and the
trend triangles stay `--` / hidden in the sim. Verify those on the watch (or by playing
back a real GPS track).

### Simulator test data flag

The sim never feeds the GPS `Position` API, so to see the layout populated the app can
fabricate smoothly‑evolving VMG / SOG / TWA / HR (a plausible upwind leg): `sample()`
calls `sampleFake()` when `SimConfig.enabled()` is true, so the averages, trend
triangles, and wind‑shift marker all animate — press START so the model records and the
windows fill.

`SimConfig.enabled()` is a **build‑time toggle, not an in‑code flag you edit** — so a
`true` can never reach the **release / watch** build:

- `SimConfig.mc` defines two variants, `(:simdata)` → `true` and `(:notsimdata)` →
  `false`. Each build excludes one, so exactly one survives.
- The committed **`monkey.jungle`** excludes `:simdata` → `enabled()` is **false**.
  Every build from `monkey.jungle` — including the release `SailVMG.prg` — is clean; the
  only fake‑data binary in the repo is the clearly‑named `SailVMG-sim.prg` (simulator only).
- To turn it on for the sim, build with the **gitignored `monkey.sim.jungle`** (it
  excludes `:notsimdata` instead → `enabled()` is **true**):

  ```powershell
  monkeyc -d fenix3_hr -f monkey.sim.jungle -o SailVMG-sim.prg -g -w -y keys/developer_key
  monkeydo SailVMG-sim.prg fenix3_hr
  ```

  If `monkey.sim.jungle` doesn't exist (it's gitignored — recreate it locally from the
  block below), builds fall back to `monkey.jungle` and fake data stays off.

  ```
  project.manifest = manifest.xml
  base.sourcePath = source
  base.resourcePath = resources
  base.excludeAnnotations = notsimdata
  ```

## Unit tests

```powershell
monkeyc -t -d fenix3_hr -f monkey.jungle -o SailVMG_test.prg -g -w -y keys/developer_key
monkeydo SailVMG_test.prg fenix3_hr /t
```

`source/Tests.mc` (12 tests) covers VMG math, TWA normalisation, nearest‑compass wrap +
the compass list's initial index, the ring buffer (windowed average / capacity /
resize), pause stops logging, save resets the timer, the VMG trend logic, the wind‑shift
reading + its ±5° dead zone and reference‑window floor, and that start/stop feedback
never crashes.

## Sideload to the watch

The fēnix 3 HR mounts as a USB mass‑storage drive. Copy the release build to
`\GARMIN\Apps\` and eject:

```
copy SailVMG.prg  <GARMIN drive>\GARMIN\Apps\SailVMG.prg
```

Then launch **SailVMG** from the watch's START → app list.

## FIT recording

On start the app creates an `ActivityRecording` session (`SPORT_GENERIC`) and two
record‑level FIT developer fields, `vmg` (kn) and `twd` (deg), written once per second
while recording. The GPS track is recorded by the session, so the activity shows a map
when synced to Garmin Connect / downloaded to a PC.

## Implementation notes

- **Rolling averages** use a fixed‑capacity **circular buffer** of two primitive
  arrays (`RingBuffer.mc`) — no per‑second allocation, low memory, self‑bounding (so no
  per‑tick prune). Window settings are capped so the buffers can't exhaust device RAM.
- The **hero number** is the 5‑second rolling average (queried from the same buffer
  with a 5 s window). The per‑second instantaneous VMG is still written to the FIT.
- **Battery**: the dominant cost is continuous GPS + the HR sensor, both inherent to a
  VMG app. Sampling/redraw run at 1 Hz.

## Source layout

| File | Role |
|---|---|
| `SailVMGApp.mc` | `AppBase`: loads/saves settings (Object Store), `getInitialView`, TWS bands + polar target table |
| `SailVMGView.mc` | Data screens, 1 Hz sampling, SOG/TWA, polar target, trend triangles, wind‑shift marker, countdown, start/stop ring overlay, `sampleFake` |
| `SimConfig.mc` | Build‑time `enabled()` toggle for the simulator fake‑data path (annotation‑gated) |
| `SailVMGDelegate.mc` | `BehaviorDelegate` button mapping |
| `DataModel.mc` | Stats, rolling averages, recording session, pause/resume, elapsed timer |
| `VmgCalculator.mc` | VMG math |
| `RingBuffer.mc` | Circular buffer for rolling averages |
| `Util.mc` | `max`/`min`, duration formatting |
| `Notify.mc` | Vibrate / tone (guarded for devices without a tone) |
| `PauseMenuView.mc` | Pause menu + Discard (No/Yes) confirmation |
| `SettingsMenuView.mc` | Settings menu + value‑adjust delegate |
| `SettingsTWDView.mc` | TWD compass snap list (plain View) + fine adjust |
| `SettingsTwsView.mc` | TWS band picker |
| `SettingsMinVmgView.mc`, `SettingsAvgSecsView.mc`, `SettingsAvgMinView.mc` | Value‑adjust screens |
| `Tests.mc` | Unit tests (compiled only with `-t`) |

## fēnix 3 HR / CIQ 1.x gotchas (learned the hard way)

These compile but misbehave at runtime if ignored:

- `Position.Info.heading` is in **radians** (convert with `Math.toDegrees`); `speed` is m/s.
- Some union‑API symbols aren't on the device: use `ActivityRecording.SPORT_GENERIC`
  (not `SPORT_SAILING`); `FONT_NUMBER_HOT` is the largest number font that renders
  (`FONT_NUMBER_THAI_HOT` is blank on the `ww` font set).
- The legacy `WatchUi.Menu` **auto‑dismisses** on selection — never `popView` inside a
  `MenuInputDelegate.onMenuItem` (that exits the app). Worse, **chaining two legacy
  menus** (menu → menu → screen) makes the return pop‑count ambiguous *on‑device* (the
  simulator hid it): it over‑popped past the root and exited the app. If that happens
  mid‑recording, the OS auto‑saves the in‑progress activity and the next START begins a
  new one — the activity silently splits in two. Fix: keep at most one legacy menu in a
  chain; build deeper steps as plain `View` + `BehaviorDelegate` so every pop is explicit
  (this is why `Set TWD`'s compass step is a `TWDCompassView`, not a menu).
- No `Toybox.Storage` (use AppBase `get/setProperty`); self‑reference is `me`, not
  `this`; `Toybox.Math` has no `max`/`min`/`abs` (`abs()` is a method on numerics).
- Git + OneDrive: avoid history rewrites / `gc` on a repo inside OneDrive (it can lock
  pack files mid‑operation and corrupt `.git`).
