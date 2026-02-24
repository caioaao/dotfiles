#!/usr/bin/env bash
# Cross-platform notification for Claude Code

MESSAGE="Claude Code needs your input"
TITLE="Claude Code"

case "$(uname -s)" in
    Darwin)
        osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\" sound name \"Basso\""
        ;;
    Linux)
        notify-send "$TITLE" "$MESSAGE" --urgency=normal
        ;;
esac
