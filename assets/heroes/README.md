# Hero art & skins

Each class has a folder here holding its **numbered skins**. Skin `1` is the
default look; `2`, `3`, … are alternates. Skins are purely cosmetic and
**drop-in** — no registration, no code changes.

```
assets/heroes/warrior/1.png            ← default full-body
assets/heroes/warrior/1_portrait.tres  ← head-crop of 1.png (combat/formation)
assets/heroes/warrior/2.png            ← alternate skin
assets/heroes/warrior/2_portrait.tres
…
```

**Format:** full-body PNG, pixel-art (nearest-filtered). The portrait `.tres` is
a small `AtlasTexture` cropping a head/bust region out of the same PNG.

## Add a skin (no registration)

1. Drop the next number into the class folder: `<n>.png`.
2. Add `<n>_portrait.tres` beside it — copy `1_portrait.tres`, repoint its
   `ext_resource` at `<n>.png`, and adjust `region = Rect2(x, y, w, h)` to frame
   the head (default crop is `Rect2(64, 24, 128, 128)`).
3. Let Godot import the PNG once (open the editor). Done.

`ClassData.all_skins()` probes `1.png`, `2.png`, … and lists whatever exists, so
the new skin shows up in the creation Appearance cycler and the city Characters
screen automatically. `HeroArt` resolves a hero's skin at runtime and **falls
back to skin 1** whenever a file is missing, so a half-finished skin never blanks
a screen. Number them consecutively from 1 (a gap stops discovery at the gap).

## Common skins (any class)

Class-neutral art (a "jack-of-all-trades" actor) lives in a shared folder and is
usable by every class:

```
assets/heroes/common/<name>.png
assets/heroes/common/<name>_portrait.tres
```

Unlike numbered per-class skins, a common skin is **not** auto-discovered — it
needs a catalog entry (below), because it also carries a display name and, if
locked, its unlock rule. Its skin id is `common/<name>`.

## The catalog — common & locked skins

`resources/skins/catalog.tres` (a `SkinCatalog`) lists every skin that needs
metadata: common skins and any skin locked behind an unlock. Each entry is a
`SkinData`: `id` (`common/<name>` or `<class>/<n>`), `display_name` (a
translation key), `unlock` (FREE / GOLD / LEVEL / EVENT), `price`, `level_req`.

- **FREE** — usable from the start.
- **GOLD** — bought on the Characters screen for `price` gold.
- **LEVEL** — auto-granted (account-wide) when any hero reaches `level_req`.
- **EVENT** — granted by `GameState.unlock_skin(id)` (a future rare room/boss).

A plain numbered per-class skin with **no** catalog entry is simply free — drop-in
as before. Add a catalog entry only to name it, make it common, or lock it.
Ownership of unlocked skins is saved in `GameState.owned_skins`.

## Skin ids in saves

A hero stores its skin as a number string (`"2"`), `common/<name>`, or `""` for
the default. Keep a skin's id stable once heroes may have it saved.

## Current art

Each class ships `1` (default) and `2` (alternate). Add `3`, `4`, … as drawn,
plus common skins under `common/` with catalog entries.
