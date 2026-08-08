# Art still missing

Everything below is **drop-in**: put a correctly named file in the right folder
and the game picks it up at runtime. Nothing here blocks the game — each falls
back to a placeholder (tinted rectangle, borrowed background, or the built-in
font). Generated from the code, so it stays accurate if you re-check.

Ordered by how visible the gap is in play.

## 1. Skill icons — 9 missing (most visible)

These show a grey placeholder square **in combat**, on the skill buttons the
player presses every turn. All the new Conjurer/Alchemist skills plus Sanctuary.

`assets/icons/skills/<file>.png` — match the existing icons' size/style:

| File | Skill |
|------|-------|
| `conjurer_blade.png` | Conjured Blade |
| `conjurer_volley.png` | Blade Volley |
| `conjurer_sunder.png` | Sunder Edge |
| `conjurer_arsenal.png` | Arsenal |
| `alchemist_acid.png` | Acid Flask |
| `alchemist_salve.png` | Salve |
| `alchemist_brew.png` | Battle Brew |
| `alchemist_elixir.png` | Grand Elixir |
| `cleric_sanctuary.png` | Sanctuary |

## 2. Item icons — 5 missing

Placeholder square in the Market, inventory and loot rows.
`assets/icons/items/<id>.png`:

`sword_flame.png` · `dagger_iron.png` · `robe_silk.png` · `ring_vitality.png` ·
`crown_kings.png`

## 3. Screen backgrounds — 7 missing

Each currently borrows another screen's art (playable, just repetitive).
720×1280 PNG in `assets/backgrounds/` — see that folder's README for the
per-screen dim values, and draw at full brightness.

| File | Screen | Currently borrowing |
|------|--------|---------------------|
| `bg_menu.png` | Main menu / title | combat |
| `bg_city.png` | City hub | merchant stall |
| `bg_dungeon.png` | Dungeon map | combat |
| `bg_create.png` | Character creation | characters |
| `bg_formation.png` | Formação | characters |
| `bg_settings.png` | Settings | characters |
| `bg_credits.png` | Credits | combat |

## 4. Font — none yet

`assets/fonts/main.ttf` — see `assets/fonts/README.md`. Currently Godot's
built-in font. Must include pt-BR accents (ã õ ç é ê á í ú â).

## 5. Hero skins — optional

Per-class art is complete (`1`–`3`/`4` per class) plus 3 common skins. Add more
by dropping the next number in — see `assets/heroes/README.md`.

## Still deliberately out of scope

Room tile art (the map uses themed chips), city art beyond a background,
animations beyond combat particles, sound.
