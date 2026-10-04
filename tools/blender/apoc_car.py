# Procedural apocalypse car for zom-zom-zoom.
# Run inside Blender: exec(open("<path>/apoc_car.py").read())
# Builds into its own "ApocCar" scene so other scenes are untouched.
# Orientation matches the old Nissan GLB: front faces Blender -Y (glTF +Z),
# wheel centres at x=+-0.85, y=-1.407/+1.383, z=0.313, radius 0.33.
import bpy, bmesh, math
from mathutils import Vector, Matrix, Euler

SCENE = "ApocCar"
WHEEL_X, WHEEL_Z, WHEEL_R = 0.85, 0.313, 0.33
WHEEL_YS = (-1.407, 1.383)

sc = bpy.data.scenes.get(SCENE) or bpy.data.scenes.new(SCENE)
for o in list(sc.collection.all_objects):
    bpy.data.objects.remove(o, do_unlink=True)
try:
    bpy.context.window.scene = sc
except Exception:
    pass
COL = sc.collection


# ---------- materials ----------
def mat(name, col, metal=0.0, rough=0.7, emit=None, strength=4.0):
    m = bpy.data.materials.get("apoc_" + name) or bpy.data.materials.new("apoc_" + name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*col, 1)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*emit, 1)
        bsdf.inputs["Emission Strength"].default_value = strength
    m.diffuse_color = (*col, 1)
    return m

M = dict(
    paint=mat("paint", (0.20, 0.065, 0.03), 0.15, 0.85),     # faded rust-red
    primer=mat("primer", (0.30, 0.28, 0.22), 0.0, 0.9),      # sandy primer patches
    steel=mat("steel", (0.10, 0.10, 0.105), 0.6, 0.65),
    rust=mat("rust", (0.17, 0.07, 0.025), 0.3, 0.95),
    trim=mat("trim", (0.03, 0.03, 0.03), 0.2, 0.8),
    chrome=mat("chrome", (0.55, 0.55, 0.57), 1.0, 0.35),
    glass=mat("glass", (0.03, 0.05, 0.06), 0.0, 0.15),
    tire=mat("tire", (0.025, 0.025, 0.025), 0.0, 0.95),
    rim=mat("rim", (0.22, 0.21, 0.19), 0.8, 0.5),
    head=mat("headlight", (1.0, 0.9, 0.6), 0.0, 0.3, emit=(1.0, 0.85, 0.55)),
    tail=mat("taillight", (0.8, 0.03, 0.02), 0.0, 0.3, emit=(1.0, 0.05, 0.02)),
    hazard=mat("hazard", (0.55, 0.38, 0.03), 0.1, 0.85),
    can=mat("jerrycan", (0.18, 0.25, 0.10), 0.1, 0.7),
)


# ---------- helpers ----------
def to_obj(name, bm, mats, parent=None, smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    COL.objects.link(ob)
    if parent:
        ob.parent = parent
    return ob


def xform(bm, verts, loc=(0, 0, 0), rot=(0, 0, 0), scale=None):
    if scale:
        bmesh.ops.scale(bm, vec=Vector(scale), verts=verts)
    bmesh.ops.rotate(bm, cent=Vector(), matrix=Euler(rot).to_matrix(), verts=verts)
    bmesh.ops.translate(bm, vec=Vector(loc), verts=verts)


def add_box(bm, size, loc, rot=(0, 0, 0), mi=0):
    r = bmesh.ops.create_cube(bm, size=1.0)
    for f in {f for v in r["verts"] for f in v.link_faces}:
        f.material_index = mi
    xform(bm, r["verts"], loc, rot, size)
    return r["verts"]


def box(name, size, loc, m, rot=(0, 0, 0), parent=None, bevel=0.0):
    bm = bmesh.new()
    add_box(bm, size, loc, rot)
    ob = to_obj(name, bm, [m], parent)
    if bevel:
        bev(ob, bevel)
    return ob


def bev(ob, w, angle=35):
    md = ob.modifiers.new("bevel", "BEVEL")
    md.width = w
    md.segments = 1
    md.limit_method = "ANGLE"
    md.angle_limit = math.radians(angle)


def add_cyl(bm, p1, p2, r1, r2=None, segs=8, mi=0):
    p1, p2 = Vector(p1), Vector(p2)
    d = p2 - p1
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    mtx = Matrix.Translation((p1 + p2) / 2) @ q.to_matrix().to_4x4()
    r = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs,
                              radius1=r1, radius2=r1 if r2 is None else r2,
                              depth=d.length, matrix=mtx)
    for f in {f for v in r["verts"] for f in v.link_faces}:
        f.material_index = mi
    return r["verts"]


def tubes(name, segments, r, m, parent=None, segs=6):
    bm = bmesh.new()
    for a, b in segments:
        add_cyl(bm, a, b, r, segs=segs)
    return to_obj(name, bm, [m], parent)


def extrude_profile(bm, pts, hw, axis="x", taper=None, offset=0.0, mi=0):
    """Closed polygon pts in the plane perpendicular to `axis`, extruded +-hw.
    taper(z) -> x-scale factor (only for axis x)."""
    sides = []
    for s in (-1, 1):
        ring = []
        for a, b in pts:
            if axis == "x":
                k = taper(b) if taper else 1.0
                co = (offset + s * hw * k, a, b)
            elif axis == "z":
                co = (a, b, offset + s * hw)
            else:
                co = (a, offset + s * hw, b)
            ring.append(bm.verts.new(co))
        sides.append(ring)
    n = len(pts)
    fs = [bm.faces.new(sides[0][::-1]), bm.faces.new(sides[1])]
    for i in range(n):
        j = (i + 1) % n
        fs.append(bm.faces.new((sides[0][i], sides[0][j], sides[1][j], sides[1][i])))
    for f in fs:
        f.material_index = mi
    bmesh.ops.recalc_face_normals(bm, faces=fs)
    return fs


def lathe(bm, prof, segs=16, cx=0.0, a0=0.0, a1=2 * math.pi, closed=True, cy=0.0, cz=0.0, mi=0):
    """Revolve closed (x, r) profile around the X axis centred at (cx, cy, cz)."""
    full = closed and abs(a1 - a0 - 2 * math.pi) < 1e-6
    steps = segs if full else segs + 1
    rings = []
    for i in range(steps):
        a = a0 + (a1 - a0) * i / segs
        rings.append([bm.verts.new((cx + x, cy + r * math.cos(a), cz + r * math.sin(a))) for x, r in prof])
    n = len(prof)
    fs = []
    for i in range(segs if full else segs):
        A, B = rings[i], rings[(i + 1) % steps]
        for k in range(n):
            l = (k + 1) % n
            fs.append(bm.faces.new((A[k], A[l], B[l], B[k])))
    if not full:
        fs.append(bm.faces.new(rings[0]))
        fs.append(bm.faces.new(rings[-1][::-1]))
    for f in fs:
        f.material_index = mi
    bmesh.ops.recalc_face_normals(bm, faces=fs)
    return fs


def apply_mods(ob):
    vl = sc.view_layers[0]
    vl.update()
    dg = vl.depsgraph
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    bpy.data.meshes.remove(old)


# ---------- body ----------
root = bpy.data.objects.new("ApocCar", None)
COL.objects.link(root)

# lower hull side profile (y, z); front at -Y
hull = [(-2.30, 0.30), (-2.34, 0.62), (-2.24, 0.80), (-0.60, 0.91), (1.55, 0.93),
        (2.26, 0.90), (2.34, 0.66), (2.30, 0.30), (2.00, 0.19), (-2.00, 0.19)]
bm = bmesh.new()
extrude_profile(bm, hull, 0.95)
body = to_obj("body", bm, [M["paint"]], root)
bev(body, 0.05)
cutters = []
for y in WHEEL_YS:
    bmc = bmesh.new()
    add_cyl(bmc, (-1.5, y, WHEEL_Z), (1.5, y, WHEEL_Z), 0.44, segs=16)
    c = to_obj("cut", bmc, [])
    md = body.modifiers.new("arch", "BOOLEAN")
    md.object = c
    md.operation = "DIFFERENCE"
    cutters.append(c)
apply_mods(body)
for c in cutters:
    bpy.data.objects.remove(c, do_unlink=True)

# cabin (glass), tapered toward the roof
cabin = [(-0.62, 0.88), (0.02, 1.33), (1.00, 1.35), (1.62, 0.88)]
bm = bmesh.new()
extrude_profile(bm, cabin, 0.82, taper=lambda z: 1.0 - (z - 0.88) / 0.47 * 0.18)
to_obj("cabin_glass", bm, [M["glass"]], root)

def cab_w(z):
    return 0.82 * (1.0 - (z - 0.88) / 0.47 * 0.18) + 0.015

box("roof", (2 * cab_w(1.35), 1.06, 0.06), (0, 0.51, 1.36), M["paint"], parent=root, bevel=0.02)

# pillars
pil = []
for s in (-1, 1):
    pil += [((s * cab_w(0.88), -0.62, 0.89), (s * cab_w(1.33), 0.02, 1.34)),
            ((s * cab_w(0.9), 0.48, 0.9), (s * cab_w(1.34), 0.48, 1.35)),
            ((s * cab_w(1.35), 1.00, 1.35), (s * cab_w(0.88), 1.62, 0.89))]
tubes("pillars", pil, 0.045, M["paint"], root, segs=4)

# windshield guard bars (just in front of the glass plane)
n = Vector((0, -0.44, 0.64)).normalized() * 0.04
bars = []
for t in (0.22, 0.45, 0.68, 0.9):
    y, z = -0.62 + 0.64 * t, 0.88 + 0.45 * t
    w = cab_w(z) - 0.02
    bars.append(((-w, y + n.y, z + n.z), (w, y + n.y, z + n.z)))
for x in (-0.25, 0.25):
    bars.append(((x, -0.62 + n.y, 0.9 + n.z), (x, 0.02 + n.y, 1.33 + n.z)))
tubes("windshield_bars", bars, 0.018, M["steel"], root, segs=5)

# rear window boarded with a slotted plate
bm = bmesh.new()
rw_n = Vector((0, 0.47, 0.62)).normalized()
for i in range(3):
    t = 0.18 + i * 0.28
    y, z = 1.0 + 0.62 * t, 1.35 - 0.47 * t
    add_box(bm, (1.25 - i * 0.04, 0.025, 0.12), (0, y + rw_n.y * 0.03, z + rw_n.z * 0.03),
            rot=(math.atan2(0.62, 0.47), 0, 0))
to_obj("rear_boards", bm, [M["rust"]], root)

# side armor plates bolted over the doors + rivets
for s in (-1, 1):
    box(f"door_plate_{s}", (0.03, 1.15, 0.36), (s * 0.965, 0.18, 0.55), M["steel"],
        rot=(math.radians(2 * s), 0, 0), parent=root, bevel=0.01)
    box(f"patch_{s}", (0.02, 0.45, 0.22), (s * 0.97, -1.95, 0.6), M["primer"],
        rot=(math.radians(-6 * s), 0, 0), parent=root)
    bm = bmesh.new()
    for y in (-0.36, 0.18, 0.72):
        for z in (0.41, 0.69):
            add_cyl(bm, (s * 0.975, y, z), (s * 0.995, y, z), 0.022, segs=6)
    to_obj(f"rivets_{s}", bm, [M["chrome"]], root)
    # side window cage: two vertical bars
    tubes(f"side_bars_{s}", [((s * cab_w(0.92), y, 0.92), (s * cab_w(1.3), y, 1.31)) for y in (0.05, 0.85, 1.2)],
          0.015, M["steel"], root, segs=4)

# fender flares over each wheel (riveted arcs)
for y in WHEEL_YS:
    for s in (-1, 1):
        bm = bmesh.new()
        prof = [(0, 0.44), (0, 0.53), (0.17, 0.53), (0.17, 0.44)]
        lathe(bm, prof, segs=10, cx=s * 0.875 - (0.17 if s < 0 else 0),
              a0=math.radians(-12), a1=math.radians(192), closed=False, cy=y, cz=WHEEL_Z)
        to_obj(f"flare_{'F' if y < 0 else 'R'}{s}", bm, [M["trim"]], root)

# rust / primer patches on the paintwork
bm = bmesh.new()
for size, loc, rz in [((0.34, 0.22, 0.01), (0.42, -1.85, 0.865), 0.3), ((0.22, 0.3, 0.01), (-0.5, -0.8, 0.905), -0.4),
                      ((0.3, 0.4, 0.01), (-0.25, 0.75, 1.392), 0.6), ((0.25, 0.18, 0.01), (0.55, 1.95, 0.915), 0.2)]:
    add_box(bm, size, loc, rot=(0, 0, rz))
for s in (-1, 1):
    add_box(bm, (0.01, 0.3, 0.14), (s * 0.952, 1.75, 0.72), rot=(0.3 * s, 0, 0))
to_obj("rust_patches", bm, [M["rust"]], root)

# ---------- front ram ----------
ram = [(-2.30, 0.66), (-2.58, 0.30), (-2.50, 0.13), (-2.28, 0.22)]
bm = bmesh.new()
extrude_profile(bm, ram, 0.92)
r_ob = to_obj("ram", bm, [M["steel"]], root)
bev(r_ob, 0.02)
bm = bmesh.new()
for i, x in enumerate((-0.7, -0.35, 0.0, 0.35, 0.7)):
    add_cyl(bm, (x, -2.52, 0.32), (x, -2.74 - 0.04 * (i % 2), 0.32), 0.05, 0.0, segs=6)
to_obj("spikes", bm, [M["chrome"]], root)
bm = bmesh.new()
stripe_rot = (Matrix.Rotation(-math.atan2(0.28, 0.36), 3, "X") @ Matrix.Rotation(math.radians(35), 3, "Y")).to_euler()
for x in (-0.66, -0.22, 0.22, 0.66):
    add_box(bm, (0.12, 0.02, 0.4), (x, -2.452, 0.487), rot=stripe_rot)
to_obj("ram_hazard", bm, [M["hazard"]], root)

# headlights with cross cages, taillights
bm, bmc = bmesh.new(), bmesh.new()
cage = []
for s in (-1, 1):
    add_cyl(bm, (s * 0.66, -2.30, 0.68), (s * 0.66, -2.36, 0.68), 0.11, segs=10)
    add_cyl(bmc, (s * 0.66, -2.27, 0.68), (s * 0.66, -2.33, 0.68), 0.135, segs=10)
    cage += [((s * 0.66 - 0.12, -2.38, 0.68), (s * 0.66 + 0.12, -2.38, 0.68)),
             ((s * 0.66, -2.38, 0.56), (s * 0.66, -2.38, 0.80))]
to_obj("headlights", bm, [M["head"]], root)
to_obj("headlight_rims", bmc, [M["trim"]], root)
tubes("headlight_cages", cage, 0.012, M["steel"], root, segs=4)
bm = bmesh.new()
for s in (-1, 1):
    add_box(bm, (0.32, 0.04, 0.09), (s * 0.66, 2.33, 0.74))
to_obj("taillights", bm, [M["tail"]], root)
box("grille", (0.85, 0.03, 0.18), (0, -2.33, 0.62), M["trim"], parent=root)

# ---------- hood blower ----------
box("blower_base", (0.42, 0.62, 0.10), (0, -1.25, 0.92), M["chrome"], parent=root, bevel=0.015)
box("blower", (0.36, 0.52, 0.16), (0, -1.25, 1.04), M["steel"], parent=root, bevel=0.02)
box("scoop", (0.34, 0.26, 0.14), (0, -1.33, 1.19), M["rust"], parent=root, bevel=0.015)
box("scoop_mouth", (0.28, 0.02, 0.09), (0, -1.465, 1.19), M["trim"], parent=root)
tubes("blower_belt", [((0, -1.52, 0.94), (0, -1.52, 1.06))], 0.05, M["trim"], root, segs=8)

# ---------- exhausts ----------
pipes = []
for s in (-1, 1):
    pipes += [((s * 1.0, -0.75, 0.27), (s * 1.0, 0.85, 0.27)),
              ((s * 0.93, -0.8, 0.30), (s * 1.0, -0.72, 0.27))]
tubes("side_pipes", pipes, 0.055, M["chrome"], root, segs=8)
tubes("rear_pipes", [((s * 0.42, 2.0, 0.26), (s * 0.42, 2.42, 0.26)) for s in (-1, 1)], 0.06, M["rust"], root, segs=8)

# ---------- roof rack + jerry cans ----------
rack = []
for x in (-0.6, 0.6):
    rack.append(((x, 0.05, 1.47), (x, 0.97, 1.47)))
    rack += [((x, 0.08, 1.39), (x, 0.08, 1.47)), ((x, 0.94, 1.39), (x, 0.94, 1.47))]
for y in (0.08, 0.5, 0.94):
    rack.append(((-0.6, y, 1.47), (0.6, y, 1.47)))
tubes("roof_rack", rack, 0.02, M["trim"], root, segs=5)
box("jerrycan_a", (0.18, 0.32, 0.24), (-0.3, 0.3, 1.59), M["can"], parent=root, bevel=0.02)
box("jerrycan_b", (0.18, 0.32, 0.24), (-0.08, 0.3, 1.59), M["can"], rot=(0, 0, 0.12), parent=root, bevel=0.02)
box("crate", (0.34, 0.34, 0.2), (0.3, 0.72, 1.57), M["primer"], rot=(0, 0, -0.2), parent=root, bevel=0.01)


# ---------- wheel ----------
def build_wheel(name, parent=None, scale=1.0):
    bm = bmesh.new()
    R = WHEEL_R * scale
    hw = 0.13 * scale
    tire_prof = [(-hw, 0.2 * scale), (hw, 0.2 * scale), (hw, R - 0.04 * scale), (hw - 0.02 * scale, R - 0.015 * scale),
                 (-hw + 0.02 * scale, R - 0.015 * scale), (-hw, R - 0.04 * scale)]
    lathe(bm, tire_prof, segs=20, mi=0)
    # tread blocks
    n = 16
    for i in range(n):
        a = 2 * math.pi * i / n
        off = 0.04 * scale if i % 2 else -0.04 * scale
        for x in (off - 0.055 * scale, off + 0.055 * scale):
            v = add_box(bm, (0.085 * scale, 0.1 * scale, 0.03 * scale), (0, 0, 0), mi=0)
            xform(bm, v, loc=(x, R * math.cos(a) * 0.985, R * math.sin(a) * 0.985), rot=(a - math.pi / 2, 0, 0))
    # steel rim, dished outward (+X), hub + lugs
    rim_prof = [(-hw + 0.02 * scale, 0.05 * scale), (hw - 0.03 * scale, 0.05 * scale), (hw - 0.01 * scale, 0.205 * scale),
                (-hw + 0.02 * scale, 0.205 * scale)]
    lathe(bm, rim_prof, segs=16, mi=1)
    add_cyl(bm, (hw - 0.03 * scale, 0, 0), (hw + 0.02 * scale, 0, 0), 0.07 * scale, segs=8, mi=2)
    for i in range(5):
        a = 2 * math.pi * i / 5
        p = (hw - 0.03 * scale, 0.1 * scale * math.cos(a), 0.1 * scale * math.sin(a))
        add_cyl(bm, p, (p[0] + 0.035 * scale, p[1], p[2]), 0.018 * scale, segs=6, mi=2)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    return to_obj(name, bm, [M["tire"], M["rim"], M["chrome"]], parent)

# spare tyre lying on the trunk, strapped down
spare = build_wheel("spare_tire", root, 0.8)
spare.rotation_euler = (0, math.radians(90), 0)
spare.location = (0, 1.92, 0.93 + 0.105)
tubes("spare_strap", [((0, 1.62, 0.95), (0, 1.92, 1.15)), ((0, 1.92, 1.15), (0, 2.22, 0.95))], 0.015, M["trim"], root, segs=4)

# ---------- small air fins ----------
# twin swept tail stabilisers on the trunk corners
for s in (-1, 1):
    bm = bmesh.new()
    fin = [(1.78, -0.04), (2.28, -0.04), (2.30, 0.24), (2.12, 0.24)]
    extrude_profile(bm, [(y, 0.92 + h) for y, h in fin], 0.012, offset=s * 0.78)
    for v in bm.verts:  # slight outward cant
        v.co.x += s * max(0.0, v.co.z - 0.92) * 0.15
    to_obj(f"tail_fin_{s}", bm, [M["steel"]], root)
# tiny canards on the front corners
for s in (-1, 1):
    bm = bmesh.new()
    can = [(s * 0.93, -2.18), (s * 1.10, -2.10), (s * 1.10, -2.00), (s * 0.93, -1.90)]
    extrude_profile(bm, can, 0.01, axis="z", offset=0.56)
    f = to_obj(f"canard_{s}", bm, [M["steel"]], root)
# small dorsal fin on the roof rear edge
bm = bmesh.new()
extrude_profile(bm, [(0.55, 1.39), (1.02, 1.39), (1.02, 1.53)], 0.012)
to_obj("roof_fin", bm, [M["steel"]], root)

# ---------- standalone wheel (exported separately) + preview copies ----------
wroot = bpy.data.objects.new("ApocWheel", None)
COL.objects.link(wroot)
wheel = build_wheel("wheel", wroot)
wroot.location = (0, 0, -3)  # parked away from the car; reset before export
for y in WHEEL_YS:
    for s in (-1, 1):
        p = bpy.data.objects.new(f"preview_wheel_{s}_{y}", wheel.data)
        COL.objects.link(p)
        p.location = (s * WHEEL_X, y, WHEEL_Z)
        if s < 0:
            p.rotation_euler = (0, 0, math.pi)

print("built", len(root.children), "parts")
