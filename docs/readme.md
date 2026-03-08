# Custom Raycast Vehicle Physics in Godot
### Summary of 5-Part YouTube Series

Source channel: https://www.youtube.com/channel/UCZ7y8O2YwS5T14hdHMe3Pzg

---

## Episode 1: Suspensions

### Key Concepts

**Spring Physics Fundamentals:**
- Springs have a rest position and apply force to return to it
- Spring force = `spring_stiffness × offset_distance` (displacement from rest)
- Real suspensions use damping to prevent oscillation
- Damping force = `damping_strength × velocity` (resistance to movement)

**Damping Ratio & Formula:**
- Critical damping prevents overdamping (where springs return too slowly)
- Damping can be tuned using: zeta value (0–1) where 0.1–0.2 = arcade cars, 0.2–1.0 = realistic
- Formula: `damping = 2 × sqrt(spring_strength × mass) × zeta`

**Raycast Car Architecture:**
- Instead of traditional wheels, raycasts pointing downward detect ground contact
- Car body is a `RigidBody3D` with box collision
- Forces applied at suspension contact points lift/stabilize the car

### Implementation Steps

1. **Scene Setup:**
   - Create `RigidBody3D` for car body
   - Add `MeshInstance3D` with box shape (2×0.5×4 units)
   - Add `CollisionShape3D` with matching box dimensions

2. **Wheel Raycasts:**
   - Create 4 `RayCast3D` nodes (FL, FR, RL, RR)
   - Front wheels at approximately `(-1.1, 0, -1.3)`, rear at `(-1.1, 0, 1.3)`
   - Mirror X positions for right-side wheels

3. **Physics Calculations:**
   - Check if raycast is colliding with ground
   - Get contact point: `raycast.get_collision_point()`
   - Get spring direction: `raycast.global_transform.basis.y` (upward vector)
   - Calculate spring length: distance from raycast origin to contact point
   - Calculate offset: `rest_distance - spring_length`
   - Apply spring force: `offset × spring_strength × direction`
   - Apply damping force: subtract `damping_strength × velocity` from spring force
   - Apply force to rigid body: `apply_force(force_vector, force_offset_position)`

4. **Get Point Velocity Function:**
   - `linear_velocity + (angular_velocity × (point - global_position))`
   - Calculates velocity at any point on the rigid body

5. **Visual Wheels:**
   - Add cylinder meshes inside each raycast (radius 0.4, height 0.15)
   - Position at `-rest_distance` Y
   - Update wheel position each frame based on spring compression

### Gotchas & Tips

- **Pulling Force Bug**: Default setup pulls car to ground even beyond rest distance.
  Fix: Set raycast target position Y to `-(rest_distance + wheel_radius)` — push only, never pull. Prevents sticky ground and flipping on ramps.
- **Mass Matters**: Spring stiffness must scale with car mass (mass 50 kg → ~5000 spring strength). Damping needs adjustment when changing mass.
- **Damping Values**: Too low = bouncy oscillation. Too high = sluggish return. Use the formula to find the range before tweaking.
- **Wheel Radius Subtraction**: Subtract wheel radius from spring length when positioning visual wheels to prevent sinking.

---

## Episode 2: Acceleration

### Key Concepts

**Motor Configuration:**
- Not all wheels need to accelerate the car — use `is_motor` flag per wheel
- Force should be applied at wheel center, not ground contact point (prevents flipping)

**Acceleration Curve System:**
- Real cars don't have constant acceleration
- Curve maps car speed (X: 0–1 = 0 to max_speed) to acceleration multiplier (Y: 0–1)
- Example shape: 30% at 0 speed → 100% at 30% max speed → taper to 10% at max speed
- Use `curve.sample_baked(speed_ratio)` to get multiplier

**Drag/Deceleration:**
- Applied on all wheels (not just motors)
- Formula: `-(forward_direction × deceleration × sign(velocity))`
- Only apply when not accelerating to avoid competing forces

**Key Fixes:**
- Raycast position lags behind at high speeds — disable auto-update, manually call `raycast.force_raycast_update()` each frame
- Use collision normal direction for spring forces (not just up vector) to prevent unintended horizontal forces on slopes

### Implementation Steps

1. **Refactor to Wheel Class** (`raycast_wheel.gd`):
   - Export variables: `spring_strength`, `spring_damping`, `rest_distance`, `wheel_radius`, `is_motor`, `is_steer`
   - Ready function: `wheel_mesh = get_child(0)`

2. **Motor Input System:**
   - Create input actions: `accelerate` (W), `decelerate` (S)
   - `motor_input` variable: -1, 0, or 1
   - Apply input to acceleration: `force_vector × motor_input`

3. **Apply Acceleration Force:**
   - Get forward direction: `-ray.global_transform.basis.z`
   - Only apply if `wheel.is_motor`
   - Force = `forward_direction × acceleration × motor_input`
   - Apply at wheel center: `ray.global_position`

4. **Acceleration Curve:**
   - Export `curve: Curve` resource
   - Points: `(0, 0.3)`, `(0.3, 1.0)`, `(0.8, 0.1)`, `(1.0, 0.1)`
   - Speed ratio: `current_forward_speed / max_speed`
   - Apply: `force × curve.sample_baked(speed_ratio)`

5. **Wheel Rotation:**
   - `wheel.rotate_x(-wheel_forward_speed × delta / wheel_radius)`

6. **Manual Raycast Update:**
   - Uncheck "Enabled" on all raycasts in inspector
   - Call `ray.force_raycast_update()` each physics frame

7. **Center of Mass Anti-Flip:**
   - Grounded: `center_of_mass = (0, 0, 0)`
   - Airborne: custom mode, place center of mass below car (e.g., `(0, -1, 0)`)

8. **Linear Damping Fix:**
   - RigidBody3D → Linear → Damp Mode: change from `Combine` to `Replace`
   - Set linear damping to 0
   - Prevents default Godot damping from interfering with tire friction

### Gotchas & Tips

- **Force Application Point**: Must apply at wheel CENTER (`ray.global_position`), not ground contact — dramatically improves stability
- **Raycast Lag Bug**: Grows worse at higher speeds. Manual update also fixes ramp/jump behavior
- **Drag Direction**: Use `sign(velocity)` to ensure drag opposes movement; `abs()` check prevents flickering near zero
- **Center of Mass Trick**: Can be quite aggressive without breaking gameplay — experiment until desired flip difficulty is reached

---

## Episode 3: Steering and Drifts

### Key Concepts

**Two Steering Methods:**
1. Fake Physics: Apply torque directly to car (easier to tune, commonly used)
2. Real Physics: Rotate wheels, let physics engine turn the car (what this series uses)

**Real Tire Physics — Cornering Force:**
- Slip angle: degrees the wheel is rotated from car velocity direction
- Lateral force = `tire_grip × lateral_velocity` (opposing sideways motion)
- Applied perpendicular to wheel orientation (local X-axis)

**Grip Curves:**
- Map slip angle / lateral velocity to grip factor (0–1)
- Typical shape: 100% grip → taper to ~0% at high slip angles
- Different curves for front/rear, or different surfaces
- Each wheel can have its own curve

**Drifting Mechanics:**
- Reduce Z-direction traction when handbrake pressed
- Car slides sideways while maintaining forward momentum
- Grip curves that lower grip at high slip angles enable natural drifting

### Implementation Steps

1. **Steering Input:**
   - Create input actions: `turn_left` (A), `turn_right` (D)
   - Variables: `tire_turn_speed` (rad/s), `tire_max_turn_degrees`
   - Only rotate front wheels (`is_steer` flag)
   - Clamp between `±tire_max_turn_degrees`
   - No input: use `move_toward()` to smoothly return to 0

2. **Lateral Force (Cornering):**
   - Side direction: `ray.global_transform.basis.x`
   - Lateral velocity: `side_direction.dot(get_point_velocity(wheel_pos))`
   - Force: `-(side_direction × lateral_velocity × mass × gravity / 4)`
   - Apply at wheel position

3. **Grip Curve:**
   - Export `grip_curve: Curve`
   - X input: `abs(lateral_velocity) / tire_velocity.length()`
   - Traction multiplier: `grip_curve.sample_baked(grip_factor)`

4. **Longitudinal Friction (Z-Force):**
   - Forward velocity: `forward_direction.dot(tire_velocity)`
   - `z_force = -(global_basis.z × forward_velocity × traction × weight)`
   - Naturally slows the car

5. **Handbrake:**
   - Input action `handbrake` (Space)
   - When pressed: reduce `z_traction` (e.g., 0.1 instead of 0.2)
   - Blend via grip curve for smooth handbrake release

6. **Skid Marks:**
   - One `GPUParticles3D` per wheel
   - Quad mesh facing Y, no gravity, vertex color as albedo
   - Color ramp: black → transparent, lifetime 1.5s
   - Position at raycast collision point each frame
   - Enable emitting when `is_slipping`

### Gotchas & Tips

- **Lateral Force at High Speed**: Force magnitude grows with speed — use mass×gravity/4 to naturally scale with load
- **Grip Curve Multi-Edit**: Can't multi-select curves in inspector. Save as `.tres` resource and quick-load to share between wheels
- **Handbrake Jerking**: Abrupt traction change causes aggressive snap — use curves to smoothly transition
- **Wheel Local Axes**: Check "Local" transform mode and verify axes — red arrow should point to wheel side

---

## Episode 4: The Basics END

### Key Concepts

**Code Organization:**
- Move all physics calculations from car script into `wheel.apply_wheel_physics(car)`
- Wheel class encapsulates suspension, motor, steering, and traction
- Car script becomes: handle input → call wheel physics → done

**Proper Collision Handling:**
- Convex collision shapes fit custom meshes better than boxes
- Raycast physics priority = -1 to execute after main physics

**Follow Camera Technique:**
- Maintain min/max distance bounds from car
- Enable Top Level flag to decouple camera from parent transforms
- Rotate toward target; check for gimbal lock vs Vector3.up

### Implementation Steps

1. **Refactor Physics into Wheel Class:**
   - `apply_wheel_physics(car: RaycastCar)` receives car reference
   - Contains: spring, tire rotation, acceleration, lateral force, longitudinal friction
   - Set contact point at wheel center before velocity calculations

2. **Car Script:**
   - Add `class_name RaycastCar`
   - Physics loop: `for wheel in wheels: wheel.apply_wheel_physics(self)`
   - Keep steering rotation and input handling in car

3. **Replace Collision Shape:**
   - Mesh → Editable Children → select mesh → Mesh menu → Create Collision Shape → Single Convex
   - Drag new shape to RigidBody3D, delete old box
   - Slightly raise so it doesn't scrape ground

4. **Raycast Physics Priority:**
   - Select all raycasts → set Physics Priority to -1
   - Ensures correct execution order after physics step

5. **Follow Camera (`car_follow_camera.gd`):**
   - Variables: `min_distance` (4), `max_distance` (8), `height` (3)
   - Distance vector clamped between min/max
   - Camera Y set to height
   - Enable Top Level on camera node
   - Optional mouse orbit: re-parent under pivot Node3D, disable Top Level during input

6. **Save Curves as Resources:**
   - Click curve arrow → Save As → `.tres`
   - Use Quick Load to assign same curve to multiple wheels
   - Make Unique for per-wheel variations

7. **Brake System:**
   - Export `z_brake_traction` on wheel (e.g., 0.25)
   - `wheel.is_braking = Input.is_action_pressed("brake")`
   - When braking: override Z traction with brake value

8. **Towing with Joints:**
   - `PinJoint3D`: simple rope-like, flexible but bouncy
   - `6DOFJoint`: rigid with angle limits, can be unstable at high speed
   - Set exclude_nodes = false to allow collisions between bodies

9. **Physics Material:**
   - Create `PhysicsMaterial`, set friction to 0
   - Assign to car RigidBody `physics_material_override`
   - Prevents scraping when landing at odd angles

### Gotchas & Tips

- **Normalized Basis Vectors**: Scaled nodes produce wrong values. Add `.normalized()` to all `global_basis` uses
- **Top Level Camera**: Must be enabled for camera to ignore parent transforms. Temporarily disable during mouse input for pivot rotation
- **Contact Point Consistency**: Set to wheel center before calculating tire velocity — improves stability across all force calculations
- **6DOF Joint Instability**: Can explode at angle limits under high speed. `PinJoint3D` is simpler and more robust

---

## Episode 5: Shapecasts and Ramps

### Key Concepts

**ShapeCast vs Raycast:**
- Raycast: single ray — fails on small gaps, can miss thin objects
- ShapeCast: sweeps a cylinder/sphere — handles bumps, gaps, ramps smoothly
- Tradeoff: more expensive but far more reliable on varied terrain

**Ramp Physics Problem:**
- Spring forces apply perpendicular to collision normal
- On slopes, this creates a component pushing car sideways
- Fix: counter spring slope forces at low speeds (acts like static friction)

**Jolt Physics Engine:**
- Available in Godot 4.6+: Project Settings → Physics 3D → Physics Engine → Jolt
- More precise and faster than default Godot physics

### Implementation Steps

1. **Switch to Jolt Physics:**
   - Project Settings → Physics 3D → Physics Engine → Jolt
   - Restart editor

2. **Ramp Sliding Fix:**
   - When `car_forward_speed < 0.5 m/s`:
     - Counter the spring force's slope component along car Y-axis
     - Increase Z traction to ~0.9 (static friction effect)
   - Prevents car from sliding down slopes when stationary

3. **Add ShapeCast Wheels:**
   - Add `ShapeCast3D` inside each wheel node (not as first child — mesh is first)
   - Attach cylinder shape (height 0.2, radius = wheel radius)
   - Rotate shape 90° on Z-axis
   - Physics Priority = -1
   - Add car's RigidBody3D as exception: `shapecast.add_exception(car_body)`
   - `max_results = 3`

4. **ShapeCast Offset:**
   - Export `shape_cast_offset` (start at 0.3)
   - Set ShapeCast Y position to offset value so it starts above ground
   - Target position X: `-(rest_distance + shape_cast_offset)`
   - Prevents shape from starting inside ground at compression

5. **Use ShapeCast in Physics:**
   - If ShapeCast available: get collision point/normal from `shapecast.get_collision_point(0)` / `get_collision_normal(0)`
   - Otherwise fall back to raycast
   - Rest of force calculations identical

6. **Low-Speed Lateral Grip Fix:**
   - When `forward_speed < 0.2 m/s`: force `grip_factor = 0`
   - Provides "static grip" — prevents sideways sliding when stopped
   - Car stops properly when hit from the side

7. **Update Point Velocity for Custom CoM:**
   - Change `global_position` to `global_center_of_mass` in point velocity formula

8. **Max Spring Force Limiter:**
   - Export `max_spring_force` (e.g., 5000)
   - `clamp(suspension_force, 0, max_spring_force)`
   - Prevents sudden compression from launching car

### Gotchas & Tips

- **Cylinder vs Sphere Shapes**: Cylinders more accurate; spheres cheaper and sometimes more stable. Collision point may alternate sides on cylinders — usually unnoticeable
- **ShapeCast Must Be at Origin**: If node position is not `(0,0,0)`, calculations break. Move the parent raycast node, not the ShapeCast
- **Offset Value Tuning**: Too low = wheel gets stuck; too high = loses ground contact. Start at 0.3, adjust per wheel size
- **Physics Priority -1**: Single most important setting for ShapeCast precision — fixes most detection failures

---

## Advanced Topics Mentioned (Not Implemented)

- **Ackermann Steering**: Front wheels at slightly different angles based on turn geometry — reduces tire slip on turns
- **Anti-Roll Bars**: Suspension stiffness adjusts dynamically during cornering
- **Pacejka Magic Formula**: Realistic tire force calculation from slip angle, load, and temperature
- **Wheel RPM & Torque Simulation**: Full transmission modeling
- **ABS / Traction Control**: Prevent wheel lockup/spin
- **Aerodynamic Drag**: Downforce and drag modeling at speed
