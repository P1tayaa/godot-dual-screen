# Changelog

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow
[Semantic Versioning](https://semver.org/).

## [0.2.0] - 2026-11-16

First tagged release.

### Added

- `DualScene`: base scene with a top and a bottom `SubViewport`, per-screen redraw modes (`ALWAYS`, `ON_CHANGE`) and
  `pixel_scale`.
- `Screens` autoload: picks `SINGLE`, `DESKTOP` or `ANDROID` mode, routes touch to the screen it lands on, swap and
  home actions, scene changes.
- Physical 2D world in millimetres (`use_physical_world_2d()`), hinge gap included.
- Device profiles (`DeviceProfile`, `ScreenSpec`) for the Anbernic RG DS (tested) and AYN Thor (not tested), plus a
  settings screen to calibrate gap and offset on the device.
- Android second-display plugin (Kotlin, prebuilt AARs) with `gl` and `readback` transports.
- Headless test runner (`TestCase`), screenshot tool, FPS label.
- Default theme with the Fusion Pixel 12 px font (Latin and Chinese).

### Fixed

- Android GL transport follows render target changes.
- `pixel_scale` also applies in the stacked layout (phones).

[0.2.0]: https://github.com/P1tayaa/godot-dual-screen/releases/tag/v0.2.0
