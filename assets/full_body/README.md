# Hero art & skins

Each hero is drawn from a **skin id**. The default skin id **equals the class id**
(`warrior`, `cleric`, `rogue`, `mage`), so the base art below already works with
no configuration. Alternate skins are optional, purely cosmetic, and drop-in.

## Two files per skin

| File | Role | Format |
|------|------|--------|
| `assets/full_body/<skin>.png` | Full-body image shown on the Characters screen. Also the **source** the portrait crops from. | PNG, pixel-art (nearest-filtered) |
| `assets/portraits/heroes/<skin>_portrait.tres` | `AtlasTexture` cropping a head/bust region out of the full-body PNG, shown in combat and formation panels. | `.tres` AtlasTexture |

The portrait `.tres` is a small AtlasTexture resource. Copy an existing one (e.g.
`warrior_portrait.tres`) and repoint its `atlas` ext_resource at your new PNG,
adjusting the `region = Rect2(x, y, w, h)` to frame the head. Reference (warrior):
`region = Rect2(64, 24, 128, 128)`.

## Registering a skin

1. Add the two files above, named `<skin>.png` / `<skin>_portrait.tres`.
2. Add the skin id to the owning class's `skins` array in
   `resources/classes/<class>.tres`. The default (class id) is always available
   and does not need listing.

That's it — `HeroArt` (`scripts/util/hero_art.gd`) resolves a hero's skin at
runtime and **falls back to the class default** whenever a skin file is missing,
so a half-finished skin never blanks a screen. No code or scene edits.

## Naming suggestion

Use `<class>_<variant>`, e.g. `warrior_b`, `mage_ember`. Keep the id stable once
it is on a saved hero — `skin_id` is stored in the save file.

## Current art

`warrior.png`, `cleric.png`, `rogue.png`, `mage.png` (+ their `_portrait.tres`) —
the four class defaults. No alternate skins ship yet; add them here as drawn.
