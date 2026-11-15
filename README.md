# Dual Screen (Godot 4.7 addon)

Two screens, one scene. Runs on dual-screen Android handhelds (Anbernic RG DS, AYN Thor), on desktop as two windows,
and stacked in one window everywhere else (phones, web, editor, headless tests).

The core of `godot-dual-core` (the examples project). Games use it as a git submodule.

## Install in a project

```bash
git submodule add <url of this repo> addons/dual_screen
git submodule update --init
```

Then enable the plugin (Project Settings > Plugins > Dual Screen). Enabling adds the `Screens` autoload, the input
actions `swap_screens` (Q / Select), `home` (H / Start), `toggle_mode` (C / Y), the addon translations and the
settings the core needs (Compatibility renderer, nearest filter, mouse emulates touch, sensors on). Set
`dual_screen/home_scene` to the scene `home` should open.

Update: `git submodule update --remote addons/dual_screen`.

## What is inside

| Path | What |
|---|---|
| `screens.gd` | `Screens` autoload (`ScreensService`): mode, device profile, swap, home, input routing |
| `dual_scene/` | `DualScene`, the base scene with a top and a bottom viewport |
| `surfaces/` | `ScreenPresenter` (window surfaces), `AndroidDisplay` (second display) |
| `physical/` | `WorldGrid` for the millimetre world |
| `profiles/` | `DeviceProfile`, `ScreenSpec`, presets in `devices/` |
| `settings/` | device settings scene (profile, gap, offset calibration) |
| `ui/` | `FpsLabel` |
| `theme/` | default theme and the Fusion Pixel 12px CJK font (OFL) |
| `testing/` | headless test runner: `$GODOT_PATH --headless --path . --script res://addons/dual_screen/testing/run_tests.gd` runs `res://tests/test_*.gd` |
| `tools/screenshot.gd` | renders a scene to PNG |
| `android/` | export plugin, built AARs, Kotlin source in `plugin_src/` (ignored by Godot) |
| `docs/` | PHILOSOPHY and CONVENTIONS every project using the core follows |

Architecture, measurements and decisions: `docs/` of `godot-dual-core`.

## Android plugin

Rebuild after changing the Kotlin code:

```bash
cd android/plugin_src && JAVA_HOME=/usr/lib/jvm/java-21-openjdk ./gradlew copyToAddon
```

Exports need Gradle builds (`gradle_build/use_gradle_build=true`) and the Android build template installed.
