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

## Skin ids in saves

A hero stores its skin as the number string (`"2"`), or `""` for the default.
Keep a skin's number stable once heroes may have it saved.

## Current art

Each class ships `1` (default) and `2` (alternate). Add `3`, `4`, … as drawn.
