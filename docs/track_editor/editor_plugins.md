# Godot 4 Editor Plugins & @tool Scripts

Research notes for building Godot editor tools, custom docks, and inspector extensions.

---

## @tool Scripts

The `@tool` annotation makes a script run **inside the editor**, not just at runtime.

```gdscript
@tool          # Must be the FIRST line
extends Node3D
```

### When _ready() runs in @tool scripts
- Runs when the scene is opened in the editor (as if the node entered the scene tree)
- Runs again every time you save the script (the scene is reloaded)
- **Gotcha**: child nodes also need `@tool` to run their own scripts in the editor — it does NOT propagate automatically

### Engine.is_editor_hint()
Use this to branch editor-only vs. runtime-only code within the same script:

```gdscript
@tool
extends Node3D

func _ready():
    if Engine.is_editor_hint():
        _setup_editor_preview()
    else:
        _start_gameplay()

func _process(delta):
    if Engine.is_editor_hint():
        # Update gizmo preview every frame
        _update_preview()
        return
    # Runtime logic below
    _move(delta)
```

### Reacting to Inspector property changes
Export vars with setters are called immediately when changed in the Inspector:

```gdscript
@tool
extends MeshInstance3D

@export var point_count: int = 8:
    set(value):
        point_count = value
        _rebuild()          # called instantly in editor when you type a new value

func _rebuild():
    if not Engine.is_editor_hint():
        return
    # regenerate mesh/preview
```

### Safety rules
- An infinite loop in a `@tool` script **hangs the editor** — always guard loops
- Avoid spawning physics bodies / playing audio in `_ready()` without `is_editor_hint()` check
- Heavy `_process()` logic in-editor will slow down the editor viewport

---

## EditorPlugin — Plugin Structure

Every Godot editor plugin lives in `res://addons/<plugin_name>/`.

**Required files:**
```
res://addons/track_editor/
    plugin.cfg          ← metadata
    plugin.gd           ← main EditorPlugin script
    track_dock.tscn     ← (optional) custom dock scene
    track_dock.gd
```

**plugin.cfg:**
```ini
[plugin]
name="Track Editor"
description="In-editor track placement and editing tool."
author="You"
version="0.1"
script="plugin.gd"
```

**Enable:** Project → Project Settings → Plugins tab → enable the plugin.

---

## EditorPlugin Lifecycle

```gdscript
# plugin.gd
@tool
extends EditorPlugin

const TrackDock = preload("res://addons/track_editor/track_dock.tscn")
var dock: Control

func _enter_tree() -> void:
    # Called when plugin is ENABLED
    # Add UI, connect signals, register sub-plugins here
    dock = TrackDock.instantiate()
    add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
    dock.editor_plugin = self   # give dock access back to plugin

func _exit_tree() -> void:
    # Called when plugin is DISABLED
    # MUST remove everything added in _enter_tree — leaks cause ghost UI
    if dock:
        remove_control_from_docks(dock)
        dock.queue_free()
        dock = null
```

**Dock slots:**
| Constant | Position |
|---|---|
| `DOCK_SLOT_LEFT_UL` | Left panel, upper tab |
| `DOCK_SLOT_LEFT_BL` | Left panel, lower tab |
| `DOCK_SLOT_RIGHT_UL` | Right panel, upper tab |
| `DOCK_SLOT_RIGHT_BL` | Right panel, lower tab |

**Bottom panel (like the output/debugger area):**
```gdscript
var bottom_panel: Control

func _enter_tree():
    bottom_panel = preload("res://addons/track_editor/bottom.tscn").instantiate()
    add_control_to_bottom_panel(bottom_panel, "Track Editor")

func _exit_tree():
    remove_control_from_bottom_panel(bottom_panel)
    bottom_panel.queue_free()
```

**Toolbar button:**
```gdscript
var toolbar_btn: Button

func _enter_tree():
    toolbar_btn = Button.new()
    toolbar_btn.text = "Track"
    toolbar_btn.toggle_mode = true
    add_control_to_container(CONTAINER_TOOLBAR, toolbar_btn)
    toolbar_btn.toggled.connect(_on_toolbar_toggled)

func _exit_tree():
    remove_control_from_container(CONTAINER_TOOLBAR, toolbar_btn)
    toolbar_btn.free()

func _on_toolbar_toggled(pressed: bool):
    # Show/hide the editing mode overlay
    pass
```

---

## Undo/Redo (Critical for any editor tool)

Every user action that modifies scene state **must** go through `EditorUndoRedoManager` so Ctrl+Z works.

```gdscript
func place_track_point(position: Vector3) -> void:
    var point_node = TrackPoint.instantiate()
    var parent = get_editor_interface().get_edited_scene_root()

    var ur = get_undo_redo()
    ur.create_action("Place Track Point")

    # What to DO
    ur.add_do_method(parent, "add_child", point_node)
    ur.add_do_reference(point_node)    # keeps node alive in redo stack
    ur.add_do_method(point_node, "set_owner", parent)
    ur.add_do_property(point_node, "position", position)

    # What to UNDO
    ur.add_undo_method(parent, "remove_child", point_node)

    ur.commit_action()
```

**Property-only changes:**
```gdscript
func move_track_point(node: Node3D, old_pos: Vector3, new_pos: Vector3) -> void:
    var ur = get_undo_redo()
    ur.create_action("Move Track Point")
    ur.add_do_property(node, "position", new_pos)
    ur.add_undo_property(node, "position", old_pos)
    # Optional: call a refresh method after applying
    ur.add_do_method(node, "update_spline")
    ur.add_undo_method(node, "update_spline")
    ur.commit_action()
```

**Key rules:**
- `add_do_reference(node)` / `add_undo_reference(node)` — prevent the engine from freeing nodes that are removed by an undo but needed by a redo
- Always bracket with `create_action()` … `commit_action()`
- Call `commit_action(false)` to execute without immediately applying (deferred)

---

## EditorInspectorPlugin — Custom Inspector Widgets

Inject custom UI into the Inspector panel for specific node/resource types.

```gdscript
# In plugin.gd _enter_tree:
var inspector_plugin = TrackInspectorPlugin.new()
add_inspector_plugin(inspector_plugin)

# In plugin.gd _exit_tree:
remove_inspector_plugin(inspector_plugin)
```

```gdscript
# track_inspector_plugin.gd
@tool
extends EditorInspectorPlugin

func _can_handle(object) -> bool:
    return object is TrackData   # only decorate your custom type

func _parse_begin(object: Object) -> void:
    # Add a button at the top of the inspector
    var btn = Button.new()
    btn.text = "Rebuild Track"
    btn.pressed.connect(func(): object.rebuild())
    add_custom_control(btn)

func _parse_property(
    object: Object, type: Variant.Type, name: String,
    hint_type: PropertyHint, hint_string: String,
    usage_flags: int, wide: bool
) -> bool:
    if name == "control_points":
        # Replace the default array editor with our custom widget
        var editor = TrackPointsEditor.new()
        add_property_editor(name, editor)
        return true   # returning true suppresses the default widget
    return false      # returning false shows the default widget
```

### EditorProperty (custom property widget)
```gdscript
# track_points_editor.gd
@tool
extends EditorProperty

var _updating := false

func _ready() -> void:
    var btn = Button.new()
    btn.text = "Edit Points..."
    add_child(btn)
    add_focusable(btn)
    btn.pressed.connect(_on_edit_pressed)
    set_label("Control Points")

func _update_property() -> void:
    # Called by the Inspector to refresh widget from current value
    _updating = true
    var points = get_edited_object()[get_edited_property()]
    # update widget display...
    _updating = false

func _on_edit_pressed() -> void:
    if _updating:
        return
    # Emit new value — Inspector and undo/redo handle the rest
    emit_changed(get_edited_property(), new_value)
```

---

## Accessing Editor State

```gdscript
# Get the currently selected node(s)
var selection = get_editor_interface().get_selection()
var selected_nodes = selection.get_selected_nodes()

# Get the root of the edited scene
var scene_root = get_editor_interface().get_edited_scene_root()

# Get the editor viewport (for 3D picking, raycasts, etc.)
var vp = get_editor_interface().get_editor_viewport_3d(0)

# Open a scene
get_editor_interface().open_scene_from_path("res://scenes/track_01.tscn")

# Get editor settings
var settings = EditorInterface.get_editor_settings()
```

---

## Forwarding Input to the Plugin (3D Viewport)

To handle mouse clicks in the 3D viewport for placing objects:

```gdscript
# In plugin.gd

var _editing := false

func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
    if not _editing:
        return EditorPlugin.AFTER_GUI_INPUT_PASS   # don't consume input

    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            # Raycast from camera to mouse position
            var from = viewport_camera.project_ray_origin(event.position)
            var to = from + viewport_camera.project_ray_normal(event.position) * 1000.0

            var space = get_editor_interface().get_edited_scene_root()\
                        .get_world_3d().direct_space_state
            var query = PhysicsRayQueryParameters3D.create(from, to)
            var result = space.intersect_ray(query)

            if result:
                place_track_point(result.position)
                return EditorPlugin.AFTER_GUI_INPUT_STOP   # consume input

    return EditorPlugin.AFTER_GUI_INPUT_PASS

func _handles(object: Object) -> bool:
    # Return true when your plugin should be "active" for the given object
    return object is TrackPath

func _edit(object: Object) -> void:
    # Called when the user selects a node your plugin handles
    _current_track = object as TrackPath
    _editing = true
```

---

## Plugin File Layout Template

```
res://addons/track_editor/
├── plugin.cfg
├── plugin.gd                  # extends EditorPlugin
├── ui/
│   ├── track_dock.tscn        # sidebar dock
│   ├── track_dock.gd
│   └── track_toolbar.gd
├── inspector/
│   ├── track_inspector_plugin.gd   # extends EditorInspectorPlugin
│   └── track_points_editor.gd      # extends EditorProperty
└── icons/
    └── track_icon.svg
```

---

## Gotchas & Best Practices

- **Always clean up in `_exit_tree`** — ghost docks and memory leaks survive plugin disable otherwise
- **`add_do_reference()`** for any node added via undo/redo — without it the engine frees the node on undo and the redo crashes
- **`@tool` does NOT propagate** — every script in a plugin that needs editor execution needs its own `@tool`
- **Heavy `@tool` `_process()` slows the editor** — guard with `if not Engine.is_editor_hint(): return` or only do work when something changed
- **Test disable/re-enable** — always test disabling and re-enabling your plugin; it's the most common source of subtle bugs
- **`set_owner()`** — any node added to the scene programmatically must have its owner set to the scene root or it won't be saved to disk

---

## Sources
- Godot 4.4 plugin docs: https://docs.godotengine.org/en/4.4/tutorials/plugins/editor/making_plugins.html
- @tool docs: https://docs.godotengine.org/en/4.4/tutorials/plugins/running_code_in_the_editor.html
- Kodeco plugin article: https://www.kodeco.com/44259876-extending-the-editor-with-plugins-in-godot
- EditorPlugin API: https://docs.godotengine.org/en/stable/classes/class_editorplugin.html
- Cyclops Level Builder (reference implementation): https://github.com/blackears/cyclopsLevelBuilder
