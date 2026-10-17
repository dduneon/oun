"""동물의 숲 스타일 헤어 메시 생성기.

art/character/oun_villager.blend 를 연 Blender에서 실행한다.
  blender art/character/oun_villager.blend --background --python art/character/build_hair.py

머리(Head) 표면 위에 헬멧처럼 얹히는 껍데기를 만든다. 방위각마다 헤어라인 높이를 정하고,
정사각 격자를 원판으로 펴서(정수리에 꼭짓점이 몰리지 않게) 머리 표면에 투영한 뒤 바깥으로 띄운다.
헤어라인 쪽으로 갈수록 얇아져 끝이 피부에 붙는다. 스타일은 STYLES에 추가한다.
"""

import math

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

# 머리 타원체(중심·반지름). 방향을 잡는 데만 쓰고 실제 표면은 Head 메시에 투영해 얻는다.
C = Vector((0, 0.0086, 0.66))
RX, RY, RZ = 0.278, 0.236, 0.244

STYLES = {
    "HAIR_AC_SHORT": dict(
        # 방위각(도, 0=정면) → 헤어라인 높이(z)
        hairline=[(0, 0.805), (46, 0.795), (66, 0.715), (78, 0.655), (85, 0.665),
                  (92, 0.700), (108, 0.680), (140, 0.540), (165, 0.480), (180, 0.470)],
        fringe_count=4.5,   # 정면 ±52° 안의 둥근 앞머리 덩어리 수
        fringe_depth=0.045,  # 덩어리가 아래로 내려오는 깊이
        color=(0.20, 0.105, 0.055),
    ),
    # 앞머리 + 턱선까지 내려오는 옆·뒷머리(여자 기본)
    "HAIR_AC_DOWN": dict(
        hairline=[(0, 0.800), (44, 0.795), (56, 0.720), (64, 0.470), (90, 0.450), (180, 0.430)],
        # 방위각 → 머리 옆면에서 수직으로 떨어지는 정도(0=두피를 따라감, 1=늘어뜨림)
        drop=[(0, 0.0), (54, 0.0), (64, 1.0), (180, 1.0)],
        fringe_count=5.5,
        fringe_depth=0.030,
        color=(0.20, 0.105, 0.055),
    ),
}

GRID = 96
THICKNESS = 0.03
EDGE_LIFT = 0.0015
Z_EQ = 0.64  # 머리가 가장 넓은 높이. 늘어뜨린 머리는 여기서부터 수직으로 떨어진다.
P_EQ = math.acos((Z_EQ - C.z) / RZ)
# 모자용 변형(<이름>_CAP): 모자 챙 띠(CapCrown 아래 끝 z≈0.705)보다 위쪽 머리를 두피에 눌러
# 모자 밖으로 삐져나오지 않게 한다. 챙 아래(옆머리·늘어뜨린 머리)는 그대로.
CAP_Z0, CAP_Z1 = 0.70, 0.73
CAP_SQUASH = 0.25


def ss(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def lerp_tab(t, tab):
    for (a0, v0), (a1, v1) in zip(tab[:-1], tab[1:]):
        if a0 <= t <= a1:
            return v0 + (v1 - v0) * ss((t - a0) / (a1 - a0))
    return tab[-1][1]


def hairline(style, adeg):
    a = abs(adeg)
    z = lerp_tab(a, style["hairline"])
    if a < 56:
        w = 1 - max(0.0, (a - 40) / 16)
        x = ((adeg + 52) / 104 * style["fringe_count"]) % 1.0
        z -= style["fringe_depth"] * math.sqrt(max(0.0, 1 - (2 * x - 1) ** 2)) * w
    return z


def build(name, style, bvh, capped=False):
    drop_tab = style.get("drop")

    def on_scalp(a, p):
        d = Vector((math.sin(p) * math.sin(a) * RX,
                    -math.sin(p) * math.cos(a) * RY,
                    math.cos(p) * RZ)).normalized()
        hit = bvh.ray_cast(C + d, -d)[0]
        pt = hit if hit else C + d * 0.25
        base = 0.026 + 0.045 * ss((math.cos(p) + 0.3) / 1.3)  # 정수리일수록 볼륨
        if capped:
            base *= 1 - (1 - CAP_SQUASH) * ss((pt.z - CAP_Z0) / (CAP_Z1 - CAP_Z0))
        return pt, d, base

    def point(a, t):
        adeg = math.degrees(a)
        hz = hairline(style, adeg)
        p = math.acos(max(-1.0, min(1.0, (hz - C.z) / RZ))) * t
        pt, d, base = on_scalp(a, p)
        e = ss((t - 0.6) / 0.4)  # 헤어라인 쪽으로 얇아짐
        scalp = pt + d * (base * (1 - e) + EDGE_LIFT * e)
        w = lerp_tab(abs(adeg), drop_tab) if drop_tab else 0.0
        if w <= 0 or hz >= Z_EQ:
            return scalp
        # 늘어뜨린 머리: 가장 넓은 곳까지 두피를 따라가다 수직으로 떨어진다.
        s1, s2 = 0.26 * P_EQ, Z_EQ - hz
        s = t * (s1 + s2)
        if s <= s1:
            pt, d, base = on_scalp(a, s / 0.26)
            hang = pt + d * base
        else:
            pt, d, base = on_scalp(a, P_EQ)
            u = (s - s1) / s2
            # 끝으로 갈수록 살짝 퍼지다가 맨 끝은 안쪽으로 둥글게 말린다.
            out = Vector((d.x, d.y, 0)).normalized() * (0.012 * ss(u) - 0.03 * ss((u - 0.82) / 0.18))
            hang = pt + d * base + out - Vector((0, 0, s - s1))
        return scalp.lerp(hang, w)

    bm = bmesh.new()
    vs = {}
    for iy in range(GRID + 1):
        for ix in range(GRID + 1):
            x, y = -1 + 2 * ix / GRID, -1 + 2 * iy / GRID
            u, v = x * math.sqrt(1 - y * y / 2), y * math.sqrt(1 - x * x / 2)
            vs[ix, iy] = bm.verts.new(point(math.atan2(u, -v), min(1.0, math.hypot(u, v))))
    for iy in range(GRID):
        for ix in range(GRID):
            bm.faces.new((vs[ix, iy], vs[ix + 1, iy], vs[ix + 1, iy + 1], vs[ix, iy + 1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    col_name = f"{name}_CAP" if capped else name
    obj_name = col_name.title().replace("_", "")
    me = bpy.data.meshes.new(obj_name)
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = True

    mat_name = f"Hair_{name}"
    mat = bpy.data.materials.get(mat_name) or bpy.data.materials["Cloth_Tee"].copy()
    mat.name = mat_name
    next(n for n in mat.node_tree.nodes if n.type == "RGB").outputs[0].default_value = (*style["color"], 1)
    me.materials.append(mat)

    col = bpy.data.collections.get(col_name) or bpy.data.collections.new(col_name)
    if col.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(col)
    for old in list(col.objects):
        bpy.data.objects.remove(old)
    ob = bpy.data.objects.new(obj_name, me)
    col.objects.link(ob)

    sm = ob.modifiers.new("Smooth", "SMOOTH")
    sm.factor, sm.iterations = 0.8, 12
    so = ob.modifiers.new("Solidify", "SOLIDIFY")
    so.thickness, so.offset, so.use_rim = THICKNESS, -1, True
    sub = ob.modifiers.new("Subsurf", "SUBSURF")
    sub.levels, sub.render_levels = 1, 2


def main():
    head = bpy.data.objects["Head"]
    bm = bmesh.new()
    bm.from_mesh(head.data)
    bm.transform(head.matrix_world)
    bvh = BVHTree.FromBMesh(bm)
    for name, style in STYLES.items():
        build(name, style, bvh)
        build(name, style, bvh, capped=True)
    bm.free()


main()
