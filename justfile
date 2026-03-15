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

# Run the main game world directly
world:
    "{{godot}}" --path "{{project}}" --scene scenes/world/world.tscn

# Check for script compilation errors (headless, no window)
check:
    "{{godot}}" --path "{{project}}" --headless --quit 2>&1 || true

# Export web build
export:
    @bash build_web.sh

# Print last Godot log without tailing
last-log:
    @cat "{{log}}"
