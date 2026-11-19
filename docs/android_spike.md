# Android export spike (roadmap R15, part 2)

Prepared 2026-11-19. Goal: an installable Android test build the owner can put on a phone, to find out what breaks outside the browser. Not a release. Nothing here is done yet; every item below is either a check before the work or something the spike changes.

## What the spike needs (none of it is installed or changed yet)

| Need | Why | Who |
| --- | --- | --- |
| An **export preset** "Android" in `game/export_presets.cfg` | Godot exports from presets. Adding one changes export settings | Owner approves (CLAUDE.md: never change CI or export settings without approval). Open it as a draft pull request |
| **Android export templates** for Godot 4.4.1 (`android_source.zip` and `android_release.apk`/`android_debug.apk` from the templates archive) | `scripts/install_godot.sh` keeps only the web templates (the full archive is about 1.2 GB) | A new download from the pinned Godot release: a dependency step, owner approves |
| **JDK 17** and the **Android SDK** (platform-tools, build-tools 34.0.0, platform 34, command-line tools, NDK r23c for Godot 4.4) | Godot calls `adb`, `apksigner` and Gradle. `java` and `javac` are present in the cloud environment, the SDK is not | Owner approves; the download hosts (`dl.google.com`, `maven.google.com`, `services.gradle.org`) must be added to the cloud network list |
| A **debug keystore** | A debug APK must be signed. Godot makes one with `keytool` on request | Generated in the session; never committed (`security.md`) |
| An **Android phone** with developer mode and USB debugging | To install and watch it. The cloud session cannot reach a phone | Owner. Alternative: the build is sent as a file (`SendUserFile`) and installed by hand |
| A **release keystore** | Only for a store build, later | Owner keeps it; stored as a CI secret, never in the repository |

## What will break outside the browser (read from the code, 2026-11-19)

| Area | Today | Native change |
| --- | --- | --- |
| Phone motion | `device_motion.gd` reads the browser's `devicemotion` through `JavaScriptBridge`; natively `JavaScriptBridge` does nothing, so there is no strike by flick, no pull, no jig | Add a native branch with `Input.get_accelerometer()` and `Input.get_gyroscope()` feeding the same `MotionGesture`; the sign and sensitivity need a test on a real phone. The permission prompt is web only |
| Save file | `user://save.json` (IndexedDB on the web) | Works unchanged in the app's data folder; check the migration and the `.bak` copy |
| Debug menu | Compiled out of the release preset by `exclude_filter="tests/*, debug/*"` | The Android preset must carry the same filter, and a debug build needs the `mera_debug` feature tag |
| Vibration | `Input.vibrate_handheld` | Needs the `VIBRATE` permission in the preset |
| Frame rate | GL Compatibility, one canvas shader, the 3D sea and sky shaders | Android Compatibility is the same renderer family; measure on the phone, then compare with the web numbers |
| Textures | `textures/vram_compression/import_etc2_astc=true` is already set | Check the export size; the web pack is 1.8 MB plus a 42 MB engine |
| Audio | Ogg and generated WAV, buses made in code | Should work; check latency of the bite cue on the phone |
| Orientation | Landscape (`orientation=0`) | Same on Android; check the safe area on phones with a notch (controls sit in the screen corners) |
| Touch input | Already touch first | Check multi-touch (two thumbs in the fight) on a real screen |
| Back button | None in the game | The Android back gesture should go back one screen, not close the app: handle `ui_cancel` / `NOTIFICATION_WM_GO_BACK_REQUEST` |

## Done when

A debug APK installs on the owner's phone, the title opens, the world walks, a bridge position fishes, a fish is landed with the phone's motion working, the save survives closing the app, and the frame rate numbers are recorded in `project_status.md` next to the web ones. No store step is part of the spike.

## Order

1. Owner approves the draft pull request that adds the preset and says which items above they accept.
2. Network list and SDK/template install (cloud setup script, like `scripts/cloud_env_setup.sh`).
3. Export a debug APK; fix what the export reports.
4. Native motion branch and the back button, with unit tests where the logic is pure.
5. Install, play, measure, write the findings here.
