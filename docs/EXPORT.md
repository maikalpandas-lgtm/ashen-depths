# Export / Demo build

Godot **4.7+**. Presets live in `export_presets.cfg` (macOS, Windows, Web).

## One-time setup

1. Open the project in Godot.
2. **Editor → Manage Export Templates** → download for your version.
3. **Project → Export…** — each preset may need a platform SDK (Xcode for macOS, etc.).

## Build

```bash
# from project root — examples (adjust godot binary name)
godot --headless --export-release "macOS" build/AshenDepths.app
godot --headless --export-release "Windows Desktop" build/AshenDepths.exe
godot --headless --export-release "Web" build/web/index.html
```

`build/` is gitignored-friendly; create it first: `mkdir -p build/web`.

## Filters

Presets exclude heavy authoring junk:

- `shots/*` (F9 captures)
- `assets/textures/raw/*`, `masters/*` (source art)

## Version

Demo version stamped **0.5.0** (Phase 5 polish).

## Audio

Music/SFX use buses **Master / Music / SFX** (`default_bus_layout.tres`).  
Volumes save to `user://audio_settings.cfg`.
