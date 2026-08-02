#!/usr/bin/env bash
# Installs the dd-cli binary to ~/.local/bin/dd-cli.
# Auto-detects the dd-cli-v*-darwin-arm64 binary in the same directory,
# makes it executable, and strips the macOS quarantine flag.
set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
INSTALL_NAME="dd-cli"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY_PATH=$(find "$SCRIPT_DIR" -maxdepth 1 -name "dd-cli-v*-darwin-arm64" -type f | head -1)

if [ -z "$BINARY_PATH" ]; then
    echo "Error: no dd-cli binary found in $SCRIPT_DIR"
    exit 1
fi

BINARY_NAME=$(basename "$BINARY_PATH")

echo "Installing $BINARY_NAME to $INSTALL_DIR/$INSTALL_NAME ..."

mkdir -p "$INSTALL_DIR"
cp "$BINARY_PATH" "$INSTALL_DIR/$INSTALL_NAME"
chmod +x "$INSTALL_DIR/$INSTALL_NAME"
if [ "$(uname)" = "Darwin" ]; then
    command -v codesign >/dev/null 2>&1 && codesign --force --sign - "$INSTALL_DIR/$INSTALL_NAME" || true
    xattr -dr com.apple.quarantine "$INSTALL_DIR/$INSTALL_NAME" 2>/dev/null || true
fi

echo "Done. You can now run: dd-cli --help"

# ---------------------------------------------------------------------------
# AI Agent Skill Install (failures here are non-fatal)
# ---------------------------------------------------------------------------
(
set +e

SKILL_SOURCE="$SCRIPT_DIR/skills/dd-cli-usage/SKILL.md"

if [ ! -f "$SKILL_SOURCE" ]; then
    echo ""
    echo "Note: skills/dd-cli-usage/SKILL.md not found — skipping agent skill install."
    exit 0
fi

if [ ! -t 0 ]; then
    echo ""
    echo "Non-interactive shell detected — skipping agent skill install."
    echo "  A copy is available at: $SCRIPT_DIR/skills/dd-cli-usage/SKILL.md"
    exit 0
fi

echo ""
echo "Which AI agent do you use? Enter a number (or multiple separated by commas):"
echo ""
echo "  1) Claude Code    (~/.claude/skills/)"
echo "  2) Cursor         (~/.cursor/skills/)"
echo "  3) Codex          (~/.agents/skills/)"
echo "  4) OpenClaw       (~/.openclaw/skills/)"
echo "  5) Grok Build     (~/.grok/skills/)"
echo "  6) Other          (you provide the path)"
echo "  7) Skip           (install skill later manually)"
echo ""
printf "Enter your selection: "
read -r AGENT_CHOICE || AGENT_CHOICE=""

if [ -z "$AGENT_CHOICE" ]; then
    echo "  No selection made — skipping agent skill install."
    echo "  A copy is available at: $SCRIPT_DIR/skills/dd-cli-usage/SKILL.md"
    exit 0
fi

# Copies SKILL.md into <parent>/dd-cli-usage/. When create_parent is "true",
# creates the parent if missing (custom paths). Otherwise skips if parent doesn't exist (presets).
install_skill() {
    local parent="$1"
    local label="$2"
    local create_parent="${3:-false}"
    local dest="$parent/dd-cli-usage"
    if [ ! -d "$parent" ]; then
        if [ "$create_parent" = "true" ]; then
            echo "  $parent does not exist — creating it."
        else
            echo "  $parent not found — is $label installed? Skipped."
            return 1
        fi
    fi
    if ! mkdir -p "$dest" 2>/dev/null || ! cp "$SKILL_SOURCE" "$dest/SKILL.md" 2>/dev/null; then
        echo "  Failed to install to $dest — check permissions. Skipped."
        return 1
    fi
    echo "  $dest/SKILL.md  ($label)"
}

INSTALLED=0

IFS=',' read -ra CHOICES <<< "$AGENT_CHOICE"
for choice in "${CHOICES[@]}"; do
    choice="$(echo "$choice" | tr -d ' ')"
    case "$choice" in
        1)
            install_skill "$HOME/.claude/skills" "Claude Code" && INSTALLED=1
            ;;
        2)
            install_skill "$HOME/.cursor/skills" "Cursor" && INSTALLED=1
            ;;
        3)
            install_skill "$HOME/.agents/skills" "Codex" && INSTALLED=1
            ;;
        4)
            install_skill "$HOME/.openclaw/skills" "OpenClaw" && INSTALLED=1
            ;;
        5)
            install_skill "$HOME/.grok/skills" "Grok Build" && INSTALLED=1
            ;;
        6)
            printf "Enter the parent folder that contains skill subfolders (absolute path): "
            read -r CUSTOM_PATH || CUSTOM_PATH=""
            CUSTOM_PATH="${CUSTOM_PATH/#\~/$HOME}"
            if [ -z "$CUSTOM_PATH" ]; then
                echo "  (no path provided, skipped)"
            elif [ "${CUSTOM_PATH#/}" = "$CUSTOM_PATH" ]; then
                echo "  Error: path must be absolute (start with / or ~/). Skipped."
            else
                install_skill "$CUSTOM_PATH" "custom" "true" && INSTALLED=1
            fi
            ;;
        7)
            ;;
        *)
            echo "  Unknown option: $choice (skipped)"
            ;;
    esac
done

echo ""
if [ "$INSTALLED" -eq 1 ]; then
    echo "Installed DoorDash CLI agent skill:"
    echo "  Your AI agent will now know about DoorDash CLI automatically."
else
    echo "Skipped agent skill install."
fi
echo "  A copy is available at: $SCRIPT_DIR/skills/dd-cli-usage/SKILL.md"
) || true
