# ⚔️ Dungeons of Praesidium

> A turn-based dungeon crawler RPG for Android, built solo in Godot 4.

[![Godot](https://img.shields.io/badge/Godot-4.6-478CBF?logo=godotengine&logoColor=white)](https://godotengine.org/)
[![Platform](https://img.shields.io/badge/platform-Android-3DDC84?logo=android&logoColor=white)](#)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

<!-- Replace with a real gameplay screenshot or GIF -->
![Gameplay screenshot](docs/screenshots/cover.png)

---

## 📖 About

**Dungeons of Praesidium** is a mobile dungeon crawler where you pick a class, descend through procedurally generated floors, and fight tactical turn-based battles. Manage your inventory, spend skill points, trade at the shop between runs — and be careful, because a total party kill has consequences.

The game is fully playable in **English and Brazilian Portuguese**.

**▶️ [Get it on Google Play - Soon]()** · **🎮 [itch.io page](https://roxtonrd.itch.io/dungeons-of-praesidium)**

---

## ✨ Features

- **Turn-based combat** with visual feedback and tactical decision-making
- **Four playable classes**, each with distinct skills and progression
- **Procedural dungeon generation** — no two runs are identical
- **Skill point (SP) progression system** for upgrading abilities between fights
- **Inventory and shop systems** for gear and consumables
- **Save/load system** with TPK (total party kill) rules that make defeat meaningful
- **Full internationalization** — English and Brazilian Portuguese (pt-BR)
- **Adjustable difficulty** and a custom UI theme

---

## 🏗️ Technical overview

Built solo in **Godot 4.6 / GDScript**, with an emphasis on maintainable architecture rather than quick prototyping.

### Data-driven design

Game content — classes, skills, items, enemies — is defined through **custom Godot `Resource` types serialized as `.tres` files** rather than hardcoded in scripts. Adding a new item or enemy means creating a resource, not editing game logic. This keeps content separate from behavior and makes balancing changes safe and fast.

### Architecture notes

| Area | Approach |
|---|---|
| Content definition | Custom `Resource` classes (`.tres`) — data-driven, no hardcoded content |
| Persistence | File-based save system with defined TPK rules |
| Localization | Godot's translation system, English + pt-BR from the start |
| Progression | SP-based skill upgrade system, decoupled from combat logic |
| Dungeon layout | Procedural generation per run |

### Development practices

This was a deliberate exercise in shipping discipline, not just in making a game:

- **Planned vertical slices** — each feature built and verified before starting the next
- **Small, focused commits** using [Conventional Commits](https://www.conventionalcommits.org/)
- **Explicit scope control** — features were deferred to v2 rather than allowed to expand the release
- **AI-assisted development** using a persistent-context workflow to keep architectural decisions consistent across sessions

---

## 🚀 Running locally

```bash
# Clone the repository
git clone https://github.com/RoxtonRD/dungeons-of-praesidium.git
```

1. Open **Godot 4.6** (or later)
2. Import the project folder
3. Press **F5** to run

To export for Android, configure the Android build template and your own keystore in Godot's export settings.

---

## 🗺️ Roadmap (v2)

- Room-based dungeon exploration
- City hub between runs
- Expanded loot and equipment variety
- Additional enemy types and encounters

---

## 🎨 Assets

Pixel art assets in this project were **AI-generated** and assembled by the author. Sound and music credits, where applicable, are listed in the in-game credits screen.

---

## 📄 License

Released under the [MIT License](LICENSE).

---

## 👤 Author

**Roberto P. Barros** — *Roxton*

Full-stack developer (TypeScript / Python) based in Brazil.

[GitHub](https://github.com/RoxtonRD) · [itch.io](https://roxtonrd.itch.io) · [LinkedIn](https://www.linkedin.com/in/robertopbarros/)
