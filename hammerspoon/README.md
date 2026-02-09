# Hammerspoon Configuration

## Keybindings

### Window Focus (vim-style directional)
| Key | Action |
|-----|--------|
| `alt+h` | Focus window to the west |
| `alt+j` | Focus window to the south |
| `alt+k` | Focus window to the north |
| `alt+l` | Focus window to the east |

Works across monitors.

### Stacked Window Cycling
| Key | Action |
|-----|--------|
| `alt+tab` | Cycle forward through overlapping windows |
| `alt+`` | Cycle backward through overlapping windows |

Windows must have at least 50% overlap to be considered "stacked."

### Hyper Key Bindings
Hyper = `cmd+alt+ctrl+shift` (mapped from `fn` via Karabiner)

| Key | Action |
|-----|--------|
| `hyper+t` | Toggle Hammerspoon console |
| `hyper+h` | Tile window left (via Karabiner → macOS) |
| `hyper+l` | Tile window right (via Karabiner → macOS) |
| `hyper+arrows` | Window tiling (via Karabiner → macOS) |
| `hyper+c` | Center window (via Karabiner → macOS) |
| `hyper+f` | Fill/maximize window (via Karabiner → macOS) |

## Files

- `init.lua` - Entry point, auto-reload watcher, IPC setup
- `hotkeys.lua` - Keybindings
- `window.lua` - Window manipulation functions

## Auto-reload

Config auto-reloads when any file in `~/.hammerspoon/` changes.
