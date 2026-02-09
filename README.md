# Hotkeys

Keyboard configuration for macOS using Karabiner-Elements and Hammerspoon.

## Setup

```bash
./install.sh
```

This symlinks the config directories to their expected locations:

- `~/.config/karabiner` → `karabiner-elements/`
- `~/.hammerspoon` → `hammerspoon/`

Karabiner requires the **directory** to be symlinked (not individual files) due to its atomic write behavior.

## Karabiner-Elements

**Hyper key**: `fn` → right-side `⌃⌥⇧⌘`. Physical left Shift is free for a Hyper+Shift layer.

| Key | Maps to | Purpose |
|-----|---------|---------|
| Hyper+C | F13 | Window centering (avoids ctrl+c in terminals) |
| Hyper+F | F16 | Fill screen |
| Hyper+H | F17 | Left half |
| Hyper+L | F18 | Right half |
| Hyper+J | F19 | Bottom half |
| Hyper+K | F20 | Top half |
| Hyper+Shift+H | shift+F17 | Move vertical split left |
| Hyper+Shift+L | shift+F18 | Move vertical split right |
| Hyper+Shift+J | shift+F19 | Move horizontal split down |
| Hyper+Shift+K | shift+F20 | Move horizontal split up |

## Hammerspoon

### Window Management

| Shortcut | Action |
|----------|--------|
| Hyper+C | Cycle center (50% → 70% → 90%) |
| Hyper+F | Fill screen |
| Hyper+H | Cycle left (half → top-left → bottom-left) |
| Hyper+L | Cycle right (half → top-right → bottom-right) |
| Hyper+J | Bottom half |
| Hyper+K | Top half |
| Hyper+1 | 4 quarters (press again to rotate) |
| Hyper+2 | Main left + 2 stacked right |
| Hyper+3 | Main right + 2 stacked left |
| Hyper+4 | 2 windows left/right (press again to swap) |
| Hyper+O | Smart tile (auto-detects window count) |

### Split Adjustment (Hyper+Shift layer)

| Shortcut | Action |
|----------|--------|
| fn+Shift+H | Move vertical split left 10% |
| fn+Shift+L | Move vertical split right 10% |
| fn+Shift+J | Move horizontal split down 10% |
| fn+Shift+K | Move horizontal split up 10% |

### Focus Navigation

| Shortcut | Action |
|----------|--------|
| Alt+H/J/K/L | Directional focus (vim-style) |
| Alt+Tab | Cycle overlapping windows forward |
| Alt+` | Cycle overlapping windows backward |
