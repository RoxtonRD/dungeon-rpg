---
name: smoke-test
description: Click through the running Dungeons of Praesidium game via the Godot MCP (menu → city → dungeon → one fight) and capture screenshots, to catch "it compiles but the screen is broken" before a PR. Use as the last step of any gameplay-engineer or ui-assets task. Editor drivers only.
---

# Smoke test (v1: refine on first use)

Only the session that holds the editor may run this (one editor, one
driver).

## Steps

1. **Start clean.** `editor_manage` `logs_clear`, then `project_run` on
   the main scene. Poll `editor_state` until `game_capture_ready` is true.
2. **Boot check.** `logs_read` with `source: "all"`. Any error means stop
   and fix. A clean game log that carries an `editor_errors_hint` means
   scripts failed to load, which is also a failure.
3. **Main menu.** `game_manage` `get_ui_elements`: the menu buttons exist.
   Screenshot with `editor_screenshot` `source: "game"`.
4. **Get a party quickly.** Prefer the dev panel's scriptable API through
   `editor_manage` `game_eval` once it exists (issue: dev cheat panel).
   Until then, click through character creation: use `get_ui_elements`
   to find each control's rect, click its centre with `game_manage`
   `input_mouse`, and type names with `input_key`.
5. **City hub → Enter Dungeon.** Click through by UI element, then
   screenshot the city and the dungeon map.
6. **One fight.** Walk into a combat room (or start one via the dev API),
   take one action with a hero, and screenshot the combat screen.
7. **Final log check.** `logs_read` again: no new errors or warnings from
   the project's scripts.
8. **Stop.** `project_manage` `stop`.

## Report (paste into the PR)

- Pass/fail per step
- The screenshots (menu, city, map, combat)
- Any log lines that appeared

If the game window is backgrounded, screenshots come back
`stale_frame: true`. Say so rather than treating it as a pass.
