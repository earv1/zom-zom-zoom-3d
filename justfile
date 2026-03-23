godot := "/Applications/Godot.app/Contents/MacOS/Godot"
project := justfile_directory()
log := `echo "$HOME/Library/Application Support/Godot/app_userdata/Zom Zom Zoom/logs/godot.log"`

# List all commands
help:
    @just --list

# Tail the Godot error log
logs:
    @bash scripts/godot_logs.sh

# Run the main scene (level select)
run:
    "{{godot}}" --path "{{project}}"

# Run the test track directly
track:
    "{{godot}}" --path "{{project}}" --scene scenes/test_track/test_track.tscn

# Run the connector visual test scene
connector-test:
    "{{godot}}" --path "{{project}}" --scene scenes/test_track/connector_visual_test.tscn

# Run the main game world directly
world:
    "{{godot}}" --path "{{project}}" --scene scenes/world/world.tscn

# Run the main game world with no audio
world-mute:
    "{{godot}}" --path "{{project}}" --scene scenes/world/world.tscn --audio-driver Dummy

# Check for script compilation + type errors (headless, no window)
# Filters out known false positives: autoloads (GameManager) and debug plugins (DebugDraw)
# that are unavailable in --script mode but work fine at runtime.
check:
    "{{godot}}" --path "{{project}}" --headless --script scripts/validate.gd 2>&1 \
        | grep "SCRIPT ERROR:" \
        | grep -v "GameManager\|DebugDraw\|Failed to compile depended" \
        || true

# Run headless unit tests via GUT
test:
    "{{godot}}" --path "{{project}}" --headless --import 2>&1 || true
    "{{godot}}" --path "{{project}}" --headless --script addons/gut/gut_cmdln.gd -- -gdir=res://tests -gexit 2>&1

# Export web build
export:
    @bash build_web.sh

# Print last Godot log without tailing
last-log:
    @cat "{{log}}"
