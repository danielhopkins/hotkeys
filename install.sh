#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

link_dir() {
    local source="$1"
    local target="$2"

    if [ -L "$target" ]; then
        echo "Removing existing symlink: $target"
        rm "$target"
    elif [ -d "$target" ]; then
        echo "Backing up existing directory: $target → ${target}.bak"
        mv "$target" "${target}.bak"
    fi

    ln -s "$source" "$target"
    echo "Linked: $target → $source"
}

link_dir "$REPO_DIR/karabiner-elements" "$HOME/.config/karabiner"
link_dir "$REPO_DIR/hammerspoon" "$HOME/.hammerspoon"

echo ""
echo "Restarting Karabiner-Elements..."
launchctl kickstart -k "gui/$(id -u)/org.pqrs.service.agent.karabiner_console_user_server" 2>/dev/null || true

echo "Reloading Hammerspoon..."
open -g hammerspoon://reload 2>/dev/null || true

echo "Done."
