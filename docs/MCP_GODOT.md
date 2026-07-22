# Godot MCP setup (Ashen Depths)

## Server

- Package: [tugcantopaloglu/godot-mcp](https://github.com/tugcantopaloglu/godot-mcp) (157 tools)
- Install path: `~/.grok/mcp/godot-mcp`
- Grok config: `~/.grok/config.toml` → `[mcp_servers.godot]`
- Godot binary: `/opt/homebrew/bin/godot` (4.7)

### Check

```bash
grok mcp list
grok mcp doctor godot
```

Should report **157 tools** and healthy handshake.

## Runtime tools (`game_*`)

Autoload registered in `project.godot`:

- `McpInteractionServer` → `res://scripts/mcp/mcp_interaction_server.gd`
- Listens on `127.0.0.1:9090` while the game is running

Copy source (if updating MCP):

```bash
cp ~/.grok/mcp/godot-mcp/build/scripts/mcp_interaction_server.gd \
   scripts/mcp/mcp_interaction_server.gd
```

## After install

1. **Restart Grok** (or open a new session) so MCP tools load.
2. Run the game once from Godot or MCP `run_project`.
3. Use tools like `get_godot_version`, `run_project`, `validate_script`, `game_screenshot`.

## Allowed projects

`GODOT_MCP_ALLOWED_DIRS` restricts `run_project` to:

- `.../GigaCode/ashen-depths`
- `.../GigaCode` (parent)

## Note

Headless scene/project tools work without the autoload.  
`game_*` tools need the game **running** with `McpInteractionServer` autoload.

## Docs MCP (godot-mcp-docs)

- Package: [Nihilantropy/godot-mcp-docs](https://github.com/Nihilantropy/godot-mcp-docs)
- Path: `~/.grok/mcp/godot-mcp-docs`
- Grok config: `[mcp_servers.godot_docs]`
- Tools: documentation tree + file lookup (official Godot docs as markdown)

### After install / update docs

```bash
cd ~/.grok/mcp/godot-mcp-docs
source .venv/bin/activate
cd docs_converter && python godot_docs_converter.py
# ensure symlink: ln -sfn docs_converter/docs ../docs
```

Restart Grok session so `godot_docs` tools load.
