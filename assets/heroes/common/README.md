# Common skins

Drop **class-neutral** hero art here — a "jack-of-all-trades" actor usable by any
class. Two files per skin:

```
assets/heroes/common/<name>.png
assets/heroes/common/<name>_portrait.tres
```

Unlike per-class numbered skins, a common skin needs a **catalog entry** in
`resources/skins/catalog.tres` (its `id` is `common/<name>`), because it also
carries a display name and, if locked, its unlock rule. See
`assets/heroes/README.md` for the full workflow.
