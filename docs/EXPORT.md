# Export / Demo build

Godot **4.7+**. Presets: `export_presets.cfg` (macOS · Windows · Web).  
Helper script: `tools/export_demo.sh`.

## Export templates (required once)

Templates for **4.7.stable** must live in:

```
~/Library/Application Support/Godot/export_templates/4.7.stable/   # macOS
# Linux: ~/.local/share/godot/export_templates/4.7.stable/
# Windows: %APPDATA%\Godot\export_templates\4.7.stable\
```

### Install via editor
**Editor → Manage Export Templates → Download and Install** (match engine version).

### Install via download (tpz)

```bash
# Example 4.7-stable
curl -fL -o /tmp/Godot_export_templates.tpz \
  "https://github.com/godotengine/godot-builds/releases/download/4.7-stable/Godot_v4.7-stable_export_templates.tpz"
mkdir -p "$HOME/Library/Application Support/Godot/export_templates"
# Godot expects the folder named like "4.7.stable" after extract
unzip -q /tmp/Godot_export_templates.tpz -d /tmp/godot_tpl
# tpz unpacks to templates/* — copy into versioned dir:
mv /tmp/godot_tpl/templates "$HOME/Library/Application Support/Godot/export_templates/4.7.stable"
```

This machine already has `4.7.stable` templates (macos.zip, windows, web, linux, android, ios).

## Build commands

```bash
cd ashen-depths
mkdir -p build/web

# All platforms the host can export
./tools/export_demo.sh all

# Or one target
./tools/export_demo.sh macos
./tools/export_demo.sh windows
./tools/export_demo.sh web
```

Equivalent Godot CLI:

```bash
godot --headless --path . --export-release "macOS" build/AshenDepths.app
godot --headless --path . --export-release "Windows Desktop" build/AshenDepths.exe
godot --headless --path . --export-release "Web" build/web/index.html
```

## Codesign (macOS)

### Demo / local (ad-hoc, no Apple Developer account)

```bash
codesign --force --deep --sign - build/AshenDepths.app
codesign -dv --verbose=2 build/AshenDepths.app
# First open: right-click → Open (Gatekeeper)
xattr -dr com.apple.quarantine build/AshenDepths.app  # if downloaded zip
```

`export_demo.sh macos` runs ad-hoc codesign automatically.

### Distribution (App Store / notarized DMG)

1. Apple Developer Program membership  
2. Create **Developer ID Application** certificate in Keychain  
3. In Godot **Project → Export → macOS**:
   - Codesign → enable, pick identity  
   - Notarization → Apple ID / app-specific password / team ID  
4. Or CLI after export:

```bash
codesign --force --deep --options runtime \
  --sign "Developer ID Application: YOUR NAME (TEAMID)" \
  build/AshenDepths.app
xcrun notarytool submit YourApp.zip --apple-id ... --team-id ... --password ... --wait
xcrun stapler staple build/AshenDepths.app
```

Godot’s export dialog can run notarization if credentials are set in the preset.

## Filters

Presets exclude:

- `shots/*`
- `assets/textures/raw/*`, `masters/*` (authoring sources)

## Version

Demo **0.5.0** (Phase 5+ polish).
