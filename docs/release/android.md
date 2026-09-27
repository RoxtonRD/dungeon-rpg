# Android debug build

How to build the debug APK from the command line and put it on a phone.
This is the Phase 0 exit ("the game runs on your phone") and the base for
the release pipeline. The release build (AAB, upload key, Play Console)
is a later task and is **not** covered here.

## What you get

`build/praesidium-debug.apk`:

- package `com.dungeons.praesidium`, version `0.1.0` (code 1)
- `minSdk 24`, **`targetSdk 36`** (Android 16), arm64-v8a only
- signed with the Godot editor's **debug** keystore
- a debug build: the dev cheat panel (D-015) is available
- `test/` and `addons/gdUnit4/` are left out by the preset's
  `exclude_filter`

Google Play requires new apps and updates to target API 36 from
31 August 2026 ([Play Console Help: target API level requirements](https://support.google.com/googleplay/android-developer/answer/11926878),
checked 2026-09-27).

## Prerequisites

All of these are already set up on Roxton's machine. They're listed so a
new machine can be set up the same way.

| What | Where |
| --- | --- |
| Godot 4.7.2 (Steam) | `C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/` |
| Export templates 4.7.2 | `…/Godot Engine/editor_data/export_templates/4.7.2.stable/` |
| Android SDK (platform 36, build-tools 36.x, platform-tools) | `C:/Users/flank/AppData/Local/Android/Sdk` |
| JDK 17 (Adoptium) | `C:/Program Files/Eclipse Adoptium/jdk-17.0.19.10-hotspot` |
| Debug keystore | `…/Godot Engine/editor_data/keystores/debug.keystore` |

The SDK, JDK and debug keystore paths live in the editor settings
(*Editor → Editor Settings → Export → Android*), which the headless export
reads too. Never copy keystore passwords into the repo or a chat.

## Build

From the repo root, in Git Bash:

```bash
tools/export_android.sh
```

It imports the project, installs the Gradle build template into `android/`
if it's missing (the folder is gitignored, so every fresh worktree needs
it), exports the debug APK with the preset "Dungeons of Praesidium", and
prints the APK path and size (about 90 MB). The first run downloads Gradle
and its dependencies, so it needs network and takes a few minutes.

## Install on your phone

### 1. Turn on USB debugging (once per phone)

1. **Settings → About phone** and tap **Build number** seven times, until
   it says you're a developer. (On some phones it's under **Software
   information**.)
2. Go back to **Settings → System → Developer options** (or search
   Settings for "Developer options") and turn on **USB debugging**.
3. Plug the phone into the PC with a USB **data** cable. When the phone
   asks "Allow USB debugging?", tick **Always allow from this computer**
   and tap **Allow**.

Check the phone is visible:

```bash
"C:/Users/flank/AppData/Local/Android/Sdk/platform-tools/adb.exe" devices
```

It should list one device with the word `device` next to it.

### 2. Install

```bash
"C:/Users/flank/AppData/Local/Android/Sdk/platform-tools/adb.exe" install -r build/praesidium-debug.apk
```

`-r` replaces an installed copy and keeps its save data. When it prints
`Success`, the game is in the app drawer as **Dungeons of Praesidium**.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `adb devices` lists nothing | Try another cable (charge-only cables don't carry data) or port. Set the phone's USB mode to **File transfer**. Some phones need the maker's USB driver on Windows. |
| `adb devices` says `unauthorized` | Unlock the phone and accept the "Allow USB debugging?" prompt. If it doesn't show, in Developer options tap **Revoke USB debugging authorizations**, unplug and plug back in. |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | The installed copy was signed with a different key (for example a build from another PC or, later, a Play build). Uninstall it first with `adb.exe uninstall com.dungeons.praesidium`. **This deletes its save data.** |
| `INSTALL_FAILED_NO_MATCHING_ABIS` | The phone isn't 64-bit ARM. The preset builds arm64 only. |
| Play Protect warns about an unknown app | Expected for a debug build that isn't from the Play Store. Choose **Install anyway**. |
| Script stops with "android/ holds the 4.7.1 build template, but the engine is 4.7.2" | The build template must match the editor version exactly. Delete the `android/` folder and run the script again; it reinstalls the right one. (The main checkout currently has 4.7.1, so this happens there once.) |
| Export fails mentioning the Java SDK, Android SDK or keystore | Check the paths in *Editor Settings → Export → Android* against the table above. |
| Game crashes or shows a black screen on the phone | Plug the phone in and read the log: `adb.exe logcat -s godot` (with the full adb path as above). Send the output to the team. |

## Notes for the release engineer

- **Boot check without a phone.** The APK can't run on a PC, so the check
  that the export filters don't break startup uses the same preset's pack
  with the Windows debug template:
  `tools/godot.sh --export-pack "Dungeons of Praesidium" build/boot-check.pck`,
  then put the `.pck` next to copies of `windows_debug_x86_64.exe` and
  `windows_debug_x86_64_console.exe` from the templates folder, named
  `praesidium.pck`, `praesidium.exe` and `praesidium.console.exe`, and run
  `praesidium.console.exe --headless --quit-after 1500` (about 10 s).
  Set `APPDATA` to a scratch folder first so the run can't touch real
  `user://` data. Export templates refuse `--main-pack`, which is why the
  files are laid out like a Windows export instead.
- **`_mcp_game_helper` isn't in exported builds.** The Godot AI addon's
  export plugin (`addons/godot_ai/export/mcp_export_plugin.gd`) removes
  that autoload from the exported `project.binary`, headless exports
  included. The addon's files still ship (about 1.2 MB, unused).
