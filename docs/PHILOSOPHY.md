# Philosophy

This core is the starting point for small dual-screen tools and games (RG DS class handhelds: two 640x480 touch
screens, a weak ARM chip). Every project forks it. Nothing here needs to be clever. Someone new should be able to open it,
read for an hour, and start working in it.

## Performance is a design rule

The target is a slow, throttled Android device. Performance is decided while designing, not fixed at the end.

- Small base resolution, integer nearest-neighbour scale. Pixel art is never filtered.
- No per-frame work that is not needed. No `_process` when a signal, Timer, Tween or AnimationPlayer can do it.
  Disable processing on idle nodes.
- A screen that does not animate does not redraw: `Redraw.ON_CHANGE` on its viewport.
- No allocations in hot loops (reuse arrays, no string building per frame). Pool anything spawned often.
- Few nodes, few draw calls: atlases, TileMapLayer, no heavy shaders, no particles unless measured.
- Static typing everywhere is also a speed rule.
- Measure with the profiler on the real device before and after anything heavy.

## Data first

- Content is data: Resources defined in `data/schema/`, stored as `.tres`. Scripts read their exported Resources.
  They never hardcode content (`if card.id == ...`).
- New content is new data, not new code. If new content needs code, the schema is missing a field: add the field, not a
  parallel system.
- Formulas are small pure functions in `data/rules/`. Numbers in, result out, nothing applied.

## A thin core

The core is what every dual-screen project shares: the two screens (`DualScene`, `Screens`), the theme, the test
harness, the Android second-display plugin. It covers the common case and nothing more.

- No speculative systems: no event bus, no state machine framework, no "manager of managers". Godot already has scenes,
  signals, Resources and groups.
- No abstraction before the third real use. Three similar lines beat a helper nobody else calls.
- No new autoload unless the state truly lives across scenes.

## Special cases are scenes

A tool, a minigame, a puzzle: anything the core does not cover is its own scene in its own folder.

Such a scene:

- lives in its own folder (`examples/<name>/` in the core, `scenes/<name>/` in a fork) with its `.tscn` and script;
- inherits `core/dual_scene/dual_scene.tscn`, so it has a top and a bottom screen;
- is built in the editor (nodes, containers, exports), so you can open it and see what it is;
- takes its inputs through `@export`, reports back through signals;
- runs on its own with F6 (stacked screens);
- has a test in `tests/` that drives it through input actions.

If two such scenes end up sharing real logic, that logic may move into the core. Not before.

## Hacky is fine, messy is not

- A local, contained shortcut is fine when it saves real work. Mark it `# HACK: <why>`.
- Not fine: hacks that leak across scenes, magic node paths, globals written from everywhere, copy-pasted logic.
- Prefer deleting code to adding code. When in doubt, do less and say what you left out.

## Tools can be big, the output stays small

`tools/` scripts and the Android plugin can be as complex as the job needs. What they produce (Resources, scenes, an
AAR) must be simple to use from the editor.

## Git

- One commit per finished piece of work, tests green, plain message saying what and why.
- Experiments go on a branch. Merge what works, drop the rest.
- Small diffs, no drive-by refactors. Editor resaves go in their own commit or with the change that caused them.
- Forks keep the core as the `upstream` remote (see `docs/FORKING.md`).
