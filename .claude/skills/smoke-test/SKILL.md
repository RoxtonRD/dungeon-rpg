---
name: smoke-test
description: Click through the running Dungeons of Praesidium game via the Godot MCP (menu → city → dungeon → one fight) and capture screenshots, to catch "it compiles but the screen is broken" before a PR. Use as the last step of any gameplay-engineer or ui-assets task. Editor drivers only.
---

# Smoke test (v1: refine on first use)

Only the session that holds the editor may run this (one editor, one
driver).

## Steps

0. **Protect Roxton's save (D-018).** Copy every `save*.json` in
   `%APPDATA%/Godot/app_userdata/Dungeons of Praesidium/` to a backup
   folder and note their MD5s. Step 4 starts a new game, which overwrites
   them. After step 8, restore them and confirm the MD5s match.
1. **Start clean.** `editor_manage` `logs_clear`, then `project_run` on
   the main scene. Poll `editor_state` until `game_capture_ready` is true.
2. **Boot check.** `logs_read` with `source: "all"`. Any error means stop
   and fix. A clean game log that carries an `editor_errors_hint` means
   scripts failed to load, which is also a failure.
3. **Main menu.** `game_manage` `get_ui_elements`: the menu buttons exist.
   Screenshot with `editor_screenshot` `source: "game"`.
4. **Get a party quickly.** Use the `DevTools` autoload (debug builds
   only, D-015) through `editor_manage` `game_eval`:
   ```gdscript
   var msg := DevTools.quick_party(["warrior", "cleric", "rogue", "mage"], 1)
   await get_tree().create_timer(1.0).timeout
   return [msg, get_tree().current_scene.scene_file_path]
   ```
   It builds a named party, starts a new game and opens the city hub. Every
   `DevTools` call returns a String; one starting with `Error:` is a fail.
   Type locals explicitly (`var f: String = ...`) in eval code: a `:=` that
   can't infer a type is a parse error that parks the game in a debugger
   break, and you must `project_manage` `stop` and relaunch.
5. **City hub → Enter Dungeon.** Screenshot the city. Click Enter Dungeon
   by UI element (`get_ui_elements`, then `input_mouse` on its centre), so
   the real button stays covered, then screenshot the dungeon map.
6. **One fight.** Start one via the dev API:
   ```gdscript
   return DevTools.start_fight(["goblin", "bat"])
   ```
   (`DevTools.list_enemies()` lists valid ids; boss ids work too.) Wait
   about a second, take one action with a hero, and screenshot the combat
   screen.
7. **Final log check.** `logs_read` again: no new errors or warnings from
   the project's scripts.
8. **Stop.** `project_manage` `stop`.

## Report (paste into the PR)

- Pass/fail per step
- The screenshots (menu, city, map, combat)
- Any log lines that appeared

If the game window is backgrounded, screenshots come back
`stale_frame: true`. Say so rather than treating it as a pass.
