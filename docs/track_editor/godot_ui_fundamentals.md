# Godot 4 UI Fundamentals

Research notes for building UI panels, HUDs, and in-editor tools.

---

## Control Node Basics

All UI in Godot is built from `Control` nodes. Key properties:

- **Anchor** — defines where a corner/edge is positioned relative to the parent's rect (0.0–1.0). Use anchor presets (Full Rect, Top Left, etc.) to lock elements to corners.
- **Offset** — pixel offset from the anchor point.
- **Size flags** — how the control grows/shrinks inside a container (see below).
- **Custom minimum size** — minimum size the control will occupy; containers respect this.

### Size Flags
Set on child controls inside containers:

| Flag | Meaning |
|---|---|
| `SIZE_FILL` | Expand to fill available space |
| `SIZE_EXPAND` | Participate in space distribution (like flex-grow) |
| `SIZE_SHRINK_CENTER` | Stay at minimum size, centered |
| `SIZE_SHRINK_BEGIN` | Stay at minimum size, aligned start |
| `SIZE_SHRINK_END` | Stay at minimum size, aligned end |

`EXPAND + FILL` together = take all remaining space (most common for stretchy elements).

---

## Container Types

Containers automatically lay out their children. **Do not set child positions manually inside a container — the container owns that.**

| Container | Behaviour |
|---|---|
| `HBoxContainer` | Horizontal row |
| `VBoxContainer` | Vertical column |
| `GridContainer` | N-column grid, fills left-to-right |
| `MarginContainer` | Adds padding around single child |
| `PanelContainer` | Like MarginContainer but with a StyleBox background |
| `CenterContainer` | Centers a single child |
| `ScrollContainer` | Scrollable viewport around a single child |
| `TabContainer` | Tabbed pages |
| `SplitContainer` (H/V) | Two resizable panels with draggable divider |

**Nesting pattern** — combine containers to build complex layouts without absolute positioning:
```
VBoxContainer (full screen)
├─ HBoxContainer (top bar)
│   ├─ Label (title)             [EXPAND+FILL]
│   └─ Button (close)
├─ HSeparator
└─ HBoxContainer (body)          [EXPAND+FILL vertically]
    ├─ VBoxContainer (sidebar)   [min width 200]
    └─ Panel (main area)         [EXPAND+FILL]
```

---

## Anchors & Responsive Layouts

### Making a panel fill the screen
```gdscript
# Code approach
control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# Or in the editor: Layout menu → Full Rect
```

### Positioning in corners
- Top-left: anchor (0, 0, 0, 0) + offsets for size
- Bottom-right: anchor (1, 1, 1, 1) + negative offsets for size
- Full stretch: anchor (0, 0, 1, 1) + zero offsets

### Multi-resolution strategy
1. Set **Project → Display → Stretch Mode** to `canvas_items` (for UI-heavy) or `viewport`
2. Set **Stretch Aspect** to `keep` or `expand`
3. Use containers + size flags instead of hardcoded positions
4. Test at multiple resolutions with the editor's viewport size picker

---

## Themes & StyleBox

Themes let you define visual properties (colors, fonts, StyleBoxes) for all controls of a type in one place.

### Theme resource
- Create a `Theme` resource (`.tres`) and assign it to a root Control node
- All descendants inherit the theme unless they override it
- Edit visually via **Inspector → Theme → Edit** or the dedicated Theme editor

### StyleBox types
| Type | Use |
|---|---|
| `StyleBoxFlat` | Solid color with border, corner radius, shadow |
| `StyleBoxTexture` | Nine-patch texture |
| `StyleBoxLine` | Just a line (for separators) |
| `StyleBoxEmpty` | Invisible — removes default styling |

### Applying per-node overrides
```gdscript
# Override a single color for this node only
button.add_theme_color_override("font_color", Color.RED)
button.add_theme_stylebox_override("normal", my_stylebox)

# Remove the override (revert to theme)
button.remove_theme_color_override("font_color")
```

### Theme type variations
Create named variants of a type (e.g. `DangerButton` from `Button`):
1. In the Theme editor → Add Type → Type = `Button`, Variation Base = `Button`
2. Rename to `DangerButton`, customize colors
3. Assign to a button: Inspector → Theme Type Variation = `DangerButton`

---

## Signals & UI Data Flow

Connect UI to game state via signals, not direct node references:

```gdscript
# Bad — tight coupling
func _process(delta):
    $HUD/HealthBar.value = player.health  # polling every frame

# Good — signal-driven
# In GameManager (already your pattern):
signal health_changed(new_health: float)

# In HUD:
func _ready():
    GameManager.health_changed.connect(_on_health_changed)

func _on_health_changed(value: float):
    health_bar.value = value
```

For editors/tools, use `EditorUndoRedoManager` instead of direct property mutation (see [editor_plugins.md](editor_plugins.md)).

---

## UI Animation

### Tween (code-driven)
```gdscript
# Animate a property
var tween = create_tween()
tween.tween_property(panel, "modulate:a", 1.0, 0.3)\
     .from(0.0)\
     .set_ease(Tween.EASE_OUT)\
     .set_trans(Tween.TRANS_CUBIC)

# Chained sequence
var tween = create_tween()
tween.tween_property(panel, "position:y", 0.0, 0.4).from(-50.0)
tween.tween_property(panel, "modulate:a", 1.0, 0.2).from(0.0)
```

### AnimationPlayer (timeline-driven)
Good for complex entrance/exit animations with multiple properties.
- Animate `position`, `scale`, `modulate`, `pivot_offset`
- Use `RESET` track to define the "off" state
- Call `play("intro")` / `play_backwards("intro")` for in/out

### Entrance animation pattern (StayAtHomeDev)
```gdscript
# Slide + fade in
func show_panel():
    panel.visible = true
    panel.modulate.a = 0.0
    panel.position.y = -30.0
    var tween = create_tween().set_parallel()
    tween.tween_property(panel, "modulate:a", 1.0, 0.25)
    tween.tween_property(panel, "position:y", 0.0, 0.25).set_ease(Tween.EASE_OUT)

func hide_panel():
    var tween = create_tween().set_parallel()
    tween.tween_property(panel, "modulate:a", 0.0, 0.2)
    tween.tween_property(panel, "position:y", -30.0, 0.2).set_ease(Tween.EASE_IN)
    await tween.finished
    panel.visible = false
```

### Delayed / staggered animations
```gdscript
# Stagger children appearing one by one
for i in items.size():
    var tween = create_tween()
    tween.tween_interval(i * 0.05)  # 50ms stagger
    tween.tween_property(items[i], "modulate:a", 1.0, 0.2)
```

---

## AnimationComponent Pattern (StayAtHomeDev — reusable hover/enter animator)

A reusable component that can be dropped as a child of **any** Button or Control to give it animated hover and entrance effects — zero changes to the parent node's script.

**Structure:**
```gdscript
# animation_component.gd
extends Node
class_name AnimationComponent

var target: Control
var default_values: Dictionary = {}

@export_group("Hover Settings")
@export var hover_scale: Vector2 = Vector2(1.05, 1.05)
@export var hover_position: Vector2 = Vector2.ZERO
@export var hover_time: float = 0.1
@export var hover_transition: Tween.TransitionType
@export var hover_easing: Tween.EaseType
@export var hover_delay: float = 0.0
@export var parallel_animations: bool = true

@export_group("Enter Settings")
@export var enter_animation: bool = false
@export var enter_scale: Vector2 = Vector2.ONE
@export var enter_modulate: Color = Color.WHITE
@export var enter_time: float = 0.5
@export var enter_delay: float = 0.0
@export var enter_transition: Tween.TransitionType
@export var enter_easing: Tween.EaseType

func _ready() -> void:
    target = get_parent()
    call_deferred("setup")   # ← MUST defer — size not ready at _ready() time

func setup() -> void:
    # Fix scale pivot to center (Control origin is top-left by default)
    target.pivot_offset = target.size / 2.0

    # Capture current values as defaults to return to on mouse_exited
    default_values = {
        "scale": target.scale,
        "position": target.position,
        "rotation": target.rotation,
        "self_modulate": target.self_modulate,
    }

    # Connect hover signals with all parameters bound
    target.mouse_entered.connect(_add_tween.bind(
        _make_hover_values(), parallel_animations,
        hover_time, hover_transition, hover_delay, hover_easing))
    target.mouse_exited.connect(_add_tween.bind(
        default_values, parallel_animations,
        hover_time, hover_transition, 0.0, hover_easing))

    if enter_animation:
        _on_enter()

func _on_enter() -> void:
    # Snap to start-of-enter state instantly, then animate to default
    var enter_values = {"scale": enter_scale, "self_modulate": enter_modulate}
    _add_tween(enter_values, true, 0.0, Tween.TRANS_LINEAR, 0.0, Tween.EASE_IN)
    _add_tween(default_values, true, enter_time, enter_transition, enter_delay, enter_easing)

func _add_tween(values: Dictionary, parallel: bool, seconds: float,
                transition: Tween.TransitionType, delay: float,
                easing: Tween.EaseType) -> void:
    var tween = get_tree().create_tween()
    tween.set_parallel(parallel)
    tween.pause()  # pause BEFORE the loop — avoids race with tween_interval

    for property in values:
        tween.tween_property(target, str(property), values[property], seconds)\
            .set_trans(transition)\
            .set_ease(easing)

    await get_tree().create_timer(delay).timeout
    tween.play()

func _make_hover_values() -> Dictionary:
    return {
        "scale": hover_scale,
        "position": target.position + hover_position,
    }
```

**Usage:** Add as a child of any Button/Control in the scene. Configure all settings in the Inspector without touching the parent script.

**Key insights from transcripts:**
- `call_deferred("setup")` is mandatory — `size` is not computed until after `_ready()` completes
- `tween.pause()` before the property loop, then `await timer` + `tween.play()` is the reliable delay pattern — `tween_interval()` inside loops is unreliable
- `str(property)` required when using Dictionary keys with `tween_property` — it expects `StringName`
- `self_modulate` for fade-in affects only that node; `modulate` propagates to children
- Tweening `size` via code works even inside a Container (bypasses the container's layout lock)
- `@export_group("Name")` organizes Inspector into collapsible sections — essential for data-heavy components
- Export `Tween.TransitionType` / `Tween.EaseType` directly — auto-generates a dropdown, no custom enum needed

---

## Inherited Scenes (GDQuest pattern)

For UI elements that share the same structure but differ in data (e.g., coin counter vs. bomb counter):

1. Build the base scene (e.g., `counter_base.tscn`) with layout + script
2. **Scene → New Inherited Scene** → select the base `.tscn`
3. In the child scene, only override what differs (texture, initial value)
4. Script changes to the base automatically propagate to all inherited scenes

This avoids duplication while keeping each instance independently configurable.

---

## Signal Funnel Architecture (GDQuest pattern)

Decouples game logic from individual UI nodes:

```
Player → (health_changed) → Interface (HUD root)
                         ↓
              LifeBar.on_health_changed()
              NumberLabel.update_text()
```

The Interface/HUD script acts as a **fan-out hub** — it receives signals from the game and dispatches to child UI nodes. Individual UI nodes only know their own local display logic.

```gdscript
# hud.gd — receives from GameManager, dispatches to children
func _ready():
    GameManager.health_changed.connect(_on_health_changed)

func _on_health_changed(value: float) -> void:
    life_bar.update(value)
    health_label.text = str(value)
```

This is equivalent to your existing `GameManager → HUD` signal pattern.

---

## Animated Health Bar (GDQuest/Godot 4)

```gdscript
# life_bar.gd
var current_health: float = 0.0
var maximum: float = 100.0

func initialize(max_val: float) -> void:
    maximum = max_val
    $Bar.max_value = maximum

func update(new_health: float) -> void:
    if new_health < current_health:
        $AnimationPlayer.play("shake")
    _animate_bar(current_health, new_health)
    current_health = new_health
    $NumberLabel.text = "%s / %s" % [int(new_health), int(maximum)]

func _animate_bar(from: float, to: float) -> void:
    var tween = create_tween()
    tween.tween_property($Bar, "value", to, 0.6)\
        .from(from)\
        .set_trans(Tween.TRANS_ELASTIC)\
        .set_ease(Tween.EASE_OUT)

# Count-up animation for the number label
func _animate_count(from: float, to: float) -> void:
    var tween = create_tween()
    tween.tween_method(_set_count_text, from, to, 0.3)\
        .set_trans(Tween.TRANS_QUAD)\
        .set_ease(Tween.EASE_OUT)

func _set_count_text(value: float) -> void:
    $NumberLabel.text = str(roundi(value)) + " / " + str(int(maximum))
```

---

## Godot 3 → 4 Migration Quick Reference

Key API changes in the GDQuest tutorials (Godot 3):

| Godot 3 | Godot 4 |
|---|---|
| `emit_signal("name", args)` | `signal_name.emit(args)` |
| `connect("signal", target, "method_string")` | `signal_name.connect(callable)` |
| `$Tween.interpolate_property(node, prop, from, to, dur, trans, ease)` + `$Tween.start()` | `create_tween().tween_property(node, prop, to, dur).from(from).set_trans(...).set_ease(...)` |
| `$Tween.interpolate_method(self, "func", from, to, dur)` | `create_tween().tween_method(callable, from, to, dur)` |
| `DynamicFont` resource | `FontFile` resource |
| Stretch mode `"2d"` | `"canvas_items"` |
| `TextureProgress` | `TextureProgressBar` |

---

## Debug UI Pattern (StayAtHomeDev)

A simple always-on debug overlay that can display any value from anywhere:

**Scene structure:**
```
DebugUI (Control — full rect, process_mode = ALWAYS)
└─ PanelContainer (top-left corner)
   └─ VBoxContainer
      └─ [Labels added procedurally]
```

**Script:**
```gdscript
# debug_ui.gd
class_name DebugUI
extends Control

var _labels: Dictionary = {}
@onready var _container: VBoxContainer = $PanelContainer/VBoxContainer

func _ready():
    # Register on autoload so it's accessible everywhere
    # e.g. Global.debug = self
    visible = false

func _input(event):
    if event.is_action_pressed("debug_toggle"):
        visible = !visible
        get_viewport().set_input_as_handled()

func add_property(id: String, value) -> void:
    if id not in _labels:
        var label = Label.new()
        label.name = id
        _container.add_child(label)
        _labels[id] = label
    _labels[id].text = "%s: %s" % [id, str(value)]
```

**Usage from any script:**
```gdscript
func _physics_process(delta):
    Global.debug.add_property("speed", linear_velocity.length())
    Global.debug.add_property("on_ground", is_on_floor())
```

---

## Common Pitfalls

- **Don't position children inside containers** — the container will override it; use size flags instead.
- **`queue_free()` vs `visible = false`** — free when the node is truly gone; hide when it needs to reappear fast (level-up screen etc.).
- **process_mode for overlays** — pause screens need `PROCESS_MODE_ALWAYS` to remain interactive while the tree is paused.
- **`CanvasLayer` for HUD** — put HUDs in a CanvasLayer (layer 1+) so they're not affected by the world camera.
- **Input eating** — call `get_viewport().set_input_as_handled()` in UI scripts to stop clicks/keys from passing through to the game.
- **Theme changes at runtime** — `add_theme_*_override()` is per-node and instant; use this for state-driven visual changes (disabled, highlighted, etc.).

---

## Sources
- GDQuest UI playlist (transcripts): `transcripts/01–09 - *.en.txt`
- StayAtHomeDev UI playlist (transcripts): `transcripts/01–11 - *.en.txt`
- Godot 4.4 docs: https://docs.godotengine.org/en/4.4/tutorials/ui/
- Febucci blog: https://blog.febucci.com/2024/11/godots-ui-tutorial-part-one/
- Uhiyama-lab theme article: https://uhiyama-lab.com/en/notes/godot/theme-system-unified-ui/
