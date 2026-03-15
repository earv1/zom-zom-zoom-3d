#!/bin/bash
# Tail the latest Godot log for Zom Zom Zoom
LOG_DIR="$HOME/Library/Application Support/Godot/app_userdata/Zom Zom Zoom/logs"
LOG_FILE="$LOG_DIR/godot.log"

if [ ! -f "$LOG_FILE" ]; then
  echo "No log file found at: $LOG_FILE"
  exit 1
fi

echo "=== Tailing Godot log (Ctrl+C to stop) ==="
echo "Log: $LOG_FILE"
echo ""
tail -f "$LOG_FILE"
