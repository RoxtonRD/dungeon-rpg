# Fonts

Drop a font file here named **`main.ttf`** (or `main.otf` / `main.woff2`) and it
becomes the game's font everywhere — menus, combat, dungeon, everything.

No scene, theme or code changes needed: `UiFont.apply()`
(`scripts/util/ui_font.gd`) runs at boot from the `Settings` autoload, finds the
file and installs it as the project theme's default font. With no file here the
game uses Godot's built-in font, so nothing breaks.

## Choosing one

The game is a pixel-art dungeon crawler in portrait, with a lot of small text
(combat log, item stats). Worth checking on device:

- A **pixel/bitmap font** matches the art but must be used at its native size (or
  exact multiples) or it turns to mush. If you pick one, also set
  `default_font_size` in `assets/ui/theme.tres` to its native size.
- A clean **serif/blackletter-ish** display font suits the fantasy tone, but keep
  it readable at ~11–14px — that's the size the party bar and item rows use.
- Whatever you choose, confirm it has the accented characters pt-BR needs:
  **ã õ ç é ê á í ú â**. Many display fonts ship Latin-basic only, which would
  break the Portuguese text.

## Adjusting size

Base sizes are set per-label in the scenes (11–26px). If a font reads too small
or large overall, set `default_font_size` on the theme rather than editing every
scene.
