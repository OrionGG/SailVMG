# SailVMG — Garmin Fenix 3 HR Activity App

This project implements a Connect IQ Activity App that computes VMG for sailing.

Build & Sideload

1. Install the Connect IQ SDK (Device: Fenix 3 HR, SDK >= 1.3.0).
2. Build with monkeyc (from SDK):

```bash
monkeyc -f manifest.xml -o SailVMG.prg -y -r
``` 

3. Use `garmin` utility or Garmin Express / Garmin Connect Mobile to sideload the .prg to the watch.

Notes & Assumptions
- The implementation is a best-effort full app scaffold; some SDK APIs (FitContributor registration details) are simplified.
- Activity recording is invoked via `ActivityRecording.getSession()` where available.
- VMG developer fields are registered via `FitContributor` if available; consumer apps must support developer fields to show VMG.

Files
- manifest.xml — app manifest
- resources/strings/strings.xml — UI strings
- source/*.mc — Monkey C source files

Open questions (answered)
1. `SESSION_SPORT_SAILING` may not exist in older SDKs; recommended fallback is `SESSION_SPORT_GENERIC`.
2. FIT developer fields are stored as record-level developer fields; Garmin Connect may not surface them by default — third-party race apps typically parse developer fields.
3. Compatibility with Race Qs / Sail Racer depends on their ability to read developer fields — this implementation writes record fields named `vmg` and `twd`.

FIT recording and developer fields
- The app attempts to register two record-level developer fields: `vmg` (float) and `twd` (float).
- Developer-field registration and session attachment is performed when the app initializes and again when a recording starts; the app writes one sample per second from `DataModel.addSample()` while recording.
- The Connect IQ SDK has historically changed FitContributor APIs across versions; this implementation uses best-effort detection and is wrapped in try/catch. If the target SDK/device does not expose the necessary FitContributor APIs the app continues to function but developer fields may not be present in the FIT file.

