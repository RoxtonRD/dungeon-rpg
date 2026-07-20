# Screen backgrounds

Full-screen art behind each screen's UI. **Format:** PNG, **720 × 1280**
(portrait, 9:16). Higher-res at the same aspect (e.g. 1080 × 1920) also works —
each screen covers-and-crops to fit.

## How to add one (no code needed)

Each screen calls `Backdrop.apply($Background, "<key>")` in its `_ready`
(`scripts/util/backdrop.gd`). At launch it looks for
`assets/backgrounds/bg_<key>.png`:

- **File present** → that screen uses your art.
- **File absent** → the screen keeps the placeholder texture wired in its
  `.tscn` (usually borrowed from another screen), so nothing ever goes blank.

So: **draw `bg_<key>.png`, drop it in this folder, done.** No scene or script
edits. (In the editor, let Godot import it once; it ships automatically.)

> Each screen dims its background via a `modulate` on the Background node (so
> the UI stays readable), shown in the table below. Draw at full brightness —
> the dimming is applied on top. If a finished piece looks too dark/light,
> tweak that node's `modulate` in the `.tscn`.

## Already have dedicated art

| Key | File | Screen |
|-----|------|--------|
| combat | `bg_combat.png` | Combat |
| boss | `bg_boss.png` | Combat (boss encounters) |
| shop | `bg_shop.png` | Mercado |
| characters | `bg_characters.png` | Personagens |
| treasure | `bg_treasure.png` | Treasure popup |
| rest | `bg_rest.png` | Rest popup |
| event_fountain | `bg_event_fountain.png` | Fountain event popup |
| event_merchant | `bg_event_merchant.png` | Merchant event popup |
| event_altar | `bg_event_altar.png` | Altar event popup |
| event_chest | `bg_event_chest.png` | Chest event popup |

## Missing — draw these (each currently borrows another screen's art)

| Priority | Draw file | Screen | Currently borrowing | Dim (modulate) |
|----------|-----------|--------|---------------------|----------------|
| ★ High | `bg_menu.png` | Main menu / title | `bg_combat` | 0.45 |
| ★ High | `bg_city.png` | City hub | `bg_event_merchant` (stall) | 0.40 |
| ★ High | `bg_dungeon.png` | Dungeon map | `bg_combat` | 0.29 |
| ○ Optional | `bg_formation.png` | Formação | `bg_characters` | 0.39 |
| ○ Optional | `bg_settings.png` | Settings | `bg_characters` | 0.30 |
| ○ Optional | `bg_credits.png` | Credits | `bg_combat` | 0.30 |

"Optional" screens already share a sensible neighbour's art — draw them only if
you want each to feel distinct. Skipping one just leaves it on its current
placeholder.
