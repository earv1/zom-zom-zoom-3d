# Shadows in 3D Platformers / Racing Games

## Context

Godot 4.6, GL Compatibility renderer (web export target). Native `Decal` node does **not** work in GL Compatibility ([#98259](https://github.com/godotengine/godot/issues/98259)).

---

## Why Blob Shadows?

Real-time directional shadows stretch sideways based on light angle — useless for showing ground distance. A blob shadow (dark oval directly under the object) is the primary gameplay cue for where the car will land.

Used in: Super Mario 64, most 3D platformers, most mobile/web racing games.

Additional reasons:
- No extra scene render pass — just one raycast + one quad draw call
- No aliasing, shadow acne, or cascade tuning needed
- Always appears correctly under the object regardless of lighting
- Real-time shadow maps in GL Compatibility have known missing features ([#67866](https://github.com/godotengine/godot/issues/67866))

---

## Options in Godot 4 + GL Compatibility

### 1. RayCast3D + QuadMesh (used in this project)

**How it works:**
- `RayCast3D` fires straight down from the car each frame
- On hit: position a flat `MeshInstance3D` at the collision point, oriented to the surface normal
- Shader draws a soft dark radial gradient circle

**Pros:** Simple, reliable, correct on slopes
**Cons:** Single ray — misses foliage/overhangs (acceptable for this game's terrain)

```gdscript
# On hit:
_mesh.global_position = hit_point + hit_normal * 0.02
var up = hit_normal
var right = up.cross(fwd).normalized()
fwd = right.cross(up).normalized()
_mesh.global_transform.basis = Basis(right, up, -fwd).rotated(right, -PI * 0.5)
```

**Shader (soft dark circle, blend_mix):**
```glsl
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float opacity : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    vec2 uv = UV - vec2(0.5);
    float dist = length(uv) * 2.0;
    float alpha = (1.0 - smoothstep(0.5, 1.0, dist)) * opacity;
    ALBEDO = vec3(0.0);
    ALPHA = alpha;
}
```

### 2. Depth-Buffer Decal Shader on BoxMesh

**How it works:** Shader samples the depth buffer, reconstructs world-space position, projects texture onto whatever geometry is inside the box volume. No raycast needed — auto-conforms to all surfaces.

**Pros:** Perfect conformity with complex terrain, no ray needed
**Cons:** More complex setup, requires depth texture access

Reference: [Purp's Compatibility Renderer Decal Shader](https://godotshaders.com/shader/purps-compatibility-renderer-decal-shader/)
Plugin: [antzGames/Godot-Compatibility-Decal-Node](https://github.com/antzGames/Godot-Compatibility-Decal-Node)

### 3. Flat QuadMesh (fixed height)

Just a quad as a child of the car, offset downward by a fixed amount. Zero cost, but clips through or hovers over uneven terrain.

### 4. Native Decal Node

**Does not work in GL Compatibility.** Forward+ / Mobile renderer only.

---

## Comparison Table

| Approach | GL Compat | Performance | Surface Conformity | Complexity |
|---|---|---|---|---|
| RayCast + QuadMesh | ✅ | Excellent | Good | Low |
| Depth-buffer shader | ✅ | Good | Excellent | Medium |
| Flat quad (fixed Y) | ✅ | Excellent | None | Trivial |
| Native Decal node | ❌ | Good | Excellent | Low |
| Real-time shadow map | Partial | Costly | N/A | High |

---

## Implementation in This Project

`scenes/world/car_blob_shadow.gd` — `CarBlobShadow` node, child of `Car` in `car.tscn`.
Creates `RayCast3D` and `MeshInstance3D` children programmatically in `_ready()`.
Exports: `max_distance`, `shadow_size`, `shadow_opacity` (tunable in editor).

---

## Sources

- [How to blob shadow? — Godot Forums](https://godotforums.org/d/41199-how-to-blob-shadow)
- [Purp's Compatibility Renderer Decal Shader — Godot Shaders](https://godotshaders.com/shader/purps-compatibility-renderer-decal-shader/)
- [Decal node GL Compat issue #98259](https://github.com/godotengine/godot/issues/98259)
- [GL Compat 3D shadows issue #67866](https://github.com/godotengine/godot/issues/67866)
- [antzGames Compatibility Decal Plugin](https://github.com/antzGames/Godot-Compatibility-Decal-Node)
- [Shadows in 3D platformer games — academic paper (DiVA)](http://www.diva-portal.org/smash/get/diva2:1441836/FULLTEXT01.pdf)
