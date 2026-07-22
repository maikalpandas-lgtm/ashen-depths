# Ashen Depths (Навьи Копи)

1st-person **grid dungeon crawl** + turn-based **card combat** (no board).  
Party of 3, backpack 5×4 (Backpack Battles-style), Slavic myth floors (Навь from floor 3).

**Engine:** Godot **4.7+**  
**Docs:** [DESIGN](docs/DESIGN.md) · [ROADMAP](docs/ROADMAP.md) · [EXPORT](docs/EXPORT.md) · [HANDOFF](docs/HANDOFF.md)

## Run

1. Install [Godot 4.7+](https://godotengine.org/)
2. Open this folder as a project
3. F5 → `scenes/main.tscn`

### Controls

| Key | Action |
|-----|--------|
| **W / S** | Step forward / back |
| **A / D** | Turn 90° |
| **Space** | Start (title) |
| **Esc** | Pause / volumes |
| **B** | Backpack |
| **C** | Deck peek |
| **R** | New dungeon (debug) |
| **F9** | Screenshot → `shots/` |

Combat: **drag** a card onto a foe (or release near the only living enemy).

## Demo loop

```
Title → explore → pack fight → card draft → (level-up) → item loot
→ merchant? → floor boss → EXIT camp shop → next floor
```

## Tests

```bash
godot --headless --script tests/run_tests.gd
```

## Audio

- SFX: Kenney CC0 (`assets/audio/sfx/`)
- Jingles: Kenney Music Jingles CC0 (`assets/audio/jingles/`)
- Explore/combat beds: short procedural loops (`assets/audio/music/`)

## Status

Phases **0–5** playable demo: labyrinth, combat, drafts, bosses, backpack, shops, music, settings, export presets.
