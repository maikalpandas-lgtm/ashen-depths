# Audio

## SFX (Kenney CC0)

See `KENNEY_LICENSE.txt`. Packs: Impact, UI, RPG, Interface, Digital.  
Play: `Sfx.play("hit")`.

## Forest biome pack (`biome = "forest"`)

Code: `Sfx.BIOME_SFX` / `Sfx.AMBIENCE` in `scripts/sfx.gd`.  
Files live in `sfx/` next to the cave pack.

| File | Role | Source |
|------|------|--------|
| `forest_step_0..3.ogg` | Leaf-litter footstep (4 variants) | Kenney **RPG Audio** `footstep_*` (CC0) + pink/brown noise crackle (ffmpeg) |
| `forest_bump.ogg` | Hit a tree | Kenney RPG `chop` + `cloth_1` (CC0), lowpassed |
| `forest_chest.ogg` | Open a wooden cache | Kenney RPG `creak_*` + `door_open_1` (CC0) |
| `forest_path.ogg` | Leave for next path / floor | Kenney RPG footsteps + cloth + leaf noise (CC0) |
| `amb_forest.ogg` | Looping forest bed (−14 dB on SFX bus) | Procedural wind (brown/pink noise) + sparse mid-loop sine chirps; **no edge events** so Godot loop is clean |

Kenney originals: <https://kenney.nl/assets/rpg-audio> (CC0).  
Mixed/processed for this project — still CC0 / public domain.

## Music

Full credits: **`MUSIC_CREDITS.md`**.

| File | Role |
|------|------|
| `music/explore_loop.mp3` | Dungeon crawl bed (Dark Ambience, CC0) |
| `music/combat_loop.mp3` | Combat bed (Battle Theme A, CC0) |
| `jingles/*.ogg` | Title / win / lose / level-up / shop (Kenney CC0) |

Buses: **Master · Music · SFX** (`default_bus_layout.tres`). Volumes: Esc menu → `user://audio_settings.cfg`.
