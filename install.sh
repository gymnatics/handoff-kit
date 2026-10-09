#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Handoff Kit — Installer"
echo "======================="
echo ""

install_cursor() {
    local target="$HOME/.cursor/skills/session-handoff"
    mkdir -p "$(dirname "$target")"
    if [ -e "$target" ]; then
        echo "  [skip] $target already exists"
    else
        ln -s "$SCRIPT_DIR/cursor/session-handoff" "$target"
        echo "  [ok]   $target -> repo"
    fi
}

install_claude_code() {
    # Agents
    mkdir -p "$HOME/.claude/agents"
    for f in "$SCRIPT_DIR"/claude-code/agents/*.md; do
        local name=$(basename "$f")
        local target="$HOME/.claude/agents/$name"
        if [ -e "$target" ]; then
            echo "  [skip] $target already exists"
        else
            ln -s "$f" "$target"
            echo "  [ok]   $target -> repo"
        fi
    done

    # Skills
    for skill_dir in "$SCRIPT_DIR"/claude-code/skills/*/; do
        local name=$(basename "$skill_dir")
        local target="$HOME/.claude/skills/$name"
        mkdir -p "$HOME/.claude/skills"
        if [ -e "$target" ]; then
            echo "  [skip] $target already exists"
        else
            ln -s "$skill_dir" "$target"
            echo "  [ok]   $target -> repo"
        fi
    done
}

install_codex() {
    # Agents
    mkdir -p "$HOME/.codex/agents"
    for f in "$SCRIPT_DIR"/codex/agents/*.toml; do
        local name=$(basename "$f")
        local target="$HOME/.codex/agents/$name"
        if [ -e "$target" ]; then
            echo "  [skip] $target already exists"
        else
            ln -s "$f" "$target"
            echo "  [ok]   $target -> repo"
        fi
    done

    # Skills
    for skill_dir in "$SCRIPT_DIR"/codex/skills/*/; do
        local name=$(basename "$skill_dir")
        local target="$HOME/.agents/skills/$name"
        mkdir -p "$HOME/.agents/skills"
        if [ -e "$target" ]; then
            echo "  [skip] $target already exists"
        else
            ln -s "$skill_dir" "$target"
            echo "  [ok]   $target -> repo"
        fi
    done
}

echo "Installing Cursor skill..."
install_cursor
echo ""

echo "Installing Claude Code agents + skills..."
install_claude_code
echo ""

echo "Installing Codex agents + skills..."
install_codex
echo ""

echo "Done. Restart any open AI tool sessions to pick up the new skills."
