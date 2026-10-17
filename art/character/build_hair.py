"""동물의 숲 스타일 헤어 메시 생성기.

art/character/oun_villager.blend 를 연 Blender에서 실행한다.
  blender art/character/oun_villager.blend --background --python art/character/build_hair.py

머리(Head) 표면 위에 헬멧처럼 얹히는 껍데기를 만든다. 방위각마다 헤어라인 높이를 정하고,
정사각 격자를 원판으로 펴서(정수리에 꼭짓점이 몰리지 않게) 머리 표면에 투영한 뒤 바깥으로 띄운다.
헤어라인 쪽으로 갈수록 얇아져 끝이 피부에 붙는다. 스타일은 STYLES에 추가한다.
껍데기 밖으로 나오는 머리(포니테일 꼬리, 땋은 머리)는 parts로 붙인다.
"""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

def srgb(hex_):
    """'#RRGGBB'(상점 아이템 colorHex) → 선형 RGB."""
    c = [int(hex_[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c)


# 머리 타원체(중심·반지름). 방향을 잡는 데만 쓰고 실제 표면은 Head 메시에 투영해 얻는다.
C = Vector((0, 0.0086, 0.66))
RX, RY, RZ = 0.278, 0.236, 0.244


def spike(adeg, pdeg, length, r, bend=(0, 0, 0), sink=0.9):
    """머리 표면 방향(방위각 adeg, 정수리에서 pdeg)에서 뻗는 뾰족한 다발(tube 점 4개).
    bend는 끝으로 갈수록 휘는 방향·세기(월드 벡터)."""
    a, p = math.radians(adeg), math.radians(pdeg)
    d = Vector((math.sin(p) * math.sin(a), -math.sin(p) * math.cos(a), math.cos(p)))
    base = C + Vector((d.x * RX, d.y * RY, d.z * RZ)) * sink
    b = Vector(bend)
    pts = [base, base + d * length * 0.45 + b * 0.15, base + d * length * 0.8 + b * 0.55,
           base + d * length + b]
    return [(*q, rr) for q, rr in zip(pts, (r, r * 0.8, r * 0.45, r * 0.06))]

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
    # 상점: 포니테일(hair_ponytail). 넘긴 머리 + 머리 옆뒤에서 고무줄로 묶은 꼬리.
    # 꼬리는 고무줄에서 조였다가 바로 통통하게 부풀고, 끝은 바깥으로 살짝 튄다(동물의 숲 포니테일).
    "HAIR_AC_PONYTAIL": dict(
        hairline=[(0, 0.830), (40, 0.820), (64, 0.730), (78, 0.665), (86, 0.675),
                  (94, 0.705), (110, 0.680), (140, 0.550), (180, 0.510)],
        fringe_count=3.5,
        fringe_depth=0.040,
        vol=0.95,
        side_vol=0.045,
        color=srgb("#B98E63"),
        parts=[
            # 캔버스 오른쪽 끝이 x≈0.42라 꼬리 바깥선은 0.40 안에 둔다.
            dict(kind="tube", points=[  # 큰 다발
                (0.20, 0.16, 0.84, 0.030), (0.28, 0.18, 0.81, 0.034), (0.32, 0.21, 0.76, 0.070),
                (0.34, 0.20, 0.66, 0.064), (0.33, 0.15, 0.56, 0.050), (0.34, 0.11, 0.49, 0.034),
                (0.37, 0.09, 0.455, 0.017)]),
            dict(kind="tube", points=[  # 앞쪽 작은 다발(덩어리가 나뉘어 보이게)
                (0.28, 0.16, 0.81, 0.030), (0.31, 0.13, 0.75, 0.048), (0.32, 0.10, 0.66, 0.040),
                (0.31, 0.08, 0.59, 0.026), (0.32, 0.07, 0.56, 0.013)]),
            dict(kind="tie", center=(0.28, 0.18, 0.81), toward=(0.32, 0.21, 0.76),
                 radius=0.040, thickness=0.018, color=srgb("#E98C7A")),
        ],
    ),
    # 상점: 양갈래 브레이드(hair_braids). 귀 뒤에서 어깨 앞으로 내려오는 땋은 머리 두 가닥.
    "HAIR_AC_BRAIDS": dict(
        hairline=[(0, 0.805), (44, 0.795), (64, 0.725), (78, 0.660), (86, 0.670),
                  (94, 0.700), (110, 0.660), (140, 0.520), (165, 0.480), (180, 0.470)],
        fringe_count=5.5,
        fringe_depth=0.030,
        vol=0.95,
        side_vol=0.045,
        color=srgb("#A87958"),
        parts=[dict(kind="braid", mirror=True, seg=0.052, points=[
            (0.23, 0.10, 0.64, 0.062), (0.27, 0.03, 0.54, 0.060), (0.26, -0.03, 0.44, 0.056),
            (0.23, -0.07, 0.35, 0.048)])],
    ),
    # 상점(남자): 휘어진 삐죽 머리(hair_spiky). 뾰족한 앞머리 + 옆·뒤에서 위로 휘어 뻗는 삐죽한 다발.
    "HAIR_AC_SPIKY": dict(
        hairline=[(0, 0.815), (46, 0.800), (66, 0.715), (78, 0.655), (85, 0.665),
                  (92, 0.700), (108, 0.680), (140, 0.540), (165, 0.480), (180, 0.470)],
        fringe_count=4.0,
        fringe_depth=0.055,
        fringe_shape="spiky",
        color=srgb("#3A2A22"),
        # 옆·뒤 다발은 모자 챙 아래에서 나오므로 모자 변형에도 남긴다. 정수리 다발은 모자 변형에서 뺀다.
        parts=[dict(kind="tube", mirror=m, cap=c, points=spike(*args)) for m, c, args in [
            (True, True, (80, 70, 0.13, 0.042, (0.0, 0.03, 0.06), 1.0)),
            (True, True, (110, 72, 0.13, 0.042, (0.0, 0.05, 0.05), 1.0)),
            (True, True, (140, 70, 0.12, 0.040, (0.0, 0.05, 0.04), 1.0)),
            (True, False, (60, 45, 0.12, 0.045, (0.0, 0.04, 0.03), 1.0)),
            (False, False, (160, 30, 0.12, 0.045, (0.0, 0.05, -0.01), 1.0)),
        ]],
    ),
    # 상점(남자): 넘긴 앞머리(hair_flick). 왼쪽 가르마에서 오른쪽 아래로 비스듬히 넘긴 앞머리.
    "HAIR_AC_FLICK": dict(
        hairline=[(0, 0.835), (46, 0.810), (66, 0.715), (78, 0.655), (85, 0.665),
                  (92, 0.700), (108, 0.680), (140, 0.540), (165, 0.480), (180, 0.470)],
        skew=[(-180, 0.0), (-70, 0.0), (-40, 0.02), (-20, 0.0), (10, -0.04), (35, -0.06),
              (55, -0.03), (75, 0.0), (180, 0.0)],
        lift=dict(a=-35, wa=30, p=28, wp=16, amount=0.06),  # 이마가 드러난 가르마 쪽 볼륨
        fringe_count=2.5,
        fringe_depth=0.015,
        vol=1.05,
        side_vol=0.02,
        color=srgb("#7A4E33"),
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
    if "skew" in style:  # 좌우 비대칭(가르마·넘긴 앞머리): 부호 있는 방위각 → 높이 보정
        z += lerp_tab(adeg, style["skew"])
    if a < 56:
        w = 1 - max(0.0, (a - 40) / 16)
        x = ((adeg + 52) / 104 * style["fringe_count"]) % 1.0
        if style.get("fringe_shape") == "spiky":  # 뾰족한 삼각 앞머리
            bump = (1 - abs(2 * x - 1)) ** 1.5
        else:
            bump = math.sqrt(max(0.0, 1 - (2 * x - 1) ** 2))
        z -= style["fringe_depth"] * bump * w
    return z


def build(name, style, bvh, capped=False):
    drop_tab = style.get("drop")
    vol = style.get("vol", 1.0)
    flare, curl = style.get("flare", 0.012), style.get("curl", 0.03)

    side_vol = style.get("side_vol", 0.0)
    lift = style.get("lift")

    def on_scalp(a, p):
        d = Vector((math.sin(p) * math.sin(a) * RX,
                    -math.sin(p) * math.cos(a) * RY,
                    math.cos(p) * RZ)).normalized()
        hit = bvh.ray_cast(C + d, -d)[0]
        pt = hit if hit else C + d * 0.25
        base = (0.026 + 0.045 * ss((math.cos(p) + 0.3) / 1.3)) * vol  # 정수리일수록 볼륨
        if side_vol:
            # 옆머리(방위각 ±90° 부근, 정수리보다 아래)를 더 부풀린다.
            base += side_vol * math.sin(a) ** 2 * ss((0.8 - math.cos(p)) / 0.6)
        if lift:
            # 가르마 쪽 이마 위 머리 뿌리를 살짝 띄운다(방위각·정수리 각도 둘 다 가우시안).
            da = (math.degrees(a) - lift["a"] + 180) % 360 - 180
            base += lift["amount"] * math.exp(-(da / lift["wa"]) ** 2
                                              - ((math.degrees(p) - lift["p"]) / lift["wp"]) ** 2)
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
            out = Vector((d.x, d.y, 0)).normalized() * (flare * ss(u) - curl * ss((u - 0.82) / 0.18))
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

    for i, part in enumerate(style.get("parts", [])):
        if capped and not part.get("cap", True):  # 모자 밖으로 뚫고 나오는 다발은 모자 변형에서 뺀다
            continue
        if part["kind"] == "tie":
            col.objects.link(tie(f"{obj_name}Part{i}", part))
            continue
        for side in ((1, -1) if part.get("mirror") else (1,)):
            pts = [(x * side, y, z, r) for x, y, z, r in part["points"]]
            make = tube if part["kind"] == "tube" else braid
            extra = {"seg": part["seg"]} if "seg" in part else {}
            obj = make(f"{obj_name}Part{i}{'L' if side < 0 else ''}", pts, mat, **extra)
            col.objects.link(obj)


def tube(name, pts, mat):
    """반지름이 변하는 매끈한 머리 다발(포니테일 꼬리)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth, cu.bevel_resolution, cu.resolution_u = 1.0, 6, 16
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    sp.points.add(len(pts) - 1)
    for p, (x, y, z, r) in zip(sp.points, pts):
        p.co, p.radius = (x, y, z, 1), r
    sp.use_endpoint_u, sp.order_u = True, 4
    cu.materials.append(mat)
    return bpy.data.objects.new(name, cu)


def tie(name, part):
    """머리끈(도넛). 꼬리가 나가는 방향을 축으로 놓는다."""
    c, t = Vector(part["center"]), Vector(part["toward"])
    bm = bmesh.new()
    seg_major, seg_minor = 32, 12
    R, r = part["radius"], part["thickness"]
    q = (t - c).normalized().to_track_quat("Z", "Y")
    rings = []
    for i in range(seg_major):
        u = 2 * math.pi * i / seg_major
        ring = []
        for j in range(seg_minor):
            v = 2 * math.pi * j / seg_minor
            p = Vector(((R + r * math.cos(v)) * math.cos(u), (R + r * math.cos(v)) * math.sin(u), r * math.sin(v)))
            ring.append(bm.verts.new(c + q @ p))
        rings.append(ring)
    for i in range(seg_major):
        a, b = rings[i], rings[(i + 1) % seg_major]
        for j in range(seg_minor):
            bm.faces.new((a[j], b[j], b[(j + 1) % seg_minor], a[(j + 1) % seg_minor]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    mat = bpy.data.materials.get(f"Tie_{name}") or bpy.data.materials["Cloth_Tee"].copy()
    mat.name = f"Tie_{name}"
    next(n for n in mat.node_tree.nodes if n.type == "RGB").outputs[0].default_value = (*part["color"], 1)
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    ob.modifiers.new("Subsurf", "SUBSURF").levels = 1
    return ob


def braid(name, pts, mat, seg=0.034):
    """폴리라인을 따라 엇갈려 눌린 타원 마디를 이어 땋은 머리처럼 만든다. 끝에는 고무줄과 작은 술."""
    path = [Vector(p[:3]) for p in pts]
    rads = [p[3] for p in pts]
    lens = [(b - a).length for a, b in zip(path[:-1], path[1:])]
    total = sum(lens)
    bm = bmesh.new()

    def at(s):
        for i, l in enumerate(lens):
            if s <= l or i == len(lens) - 1:
                u = min(1.0, s / l)
                return path[i].lerp(path[i + 1], u), (path[i + 1] - path[i]).normalized(), rads[i] + (rads[i + 1] - rads[i]) * u
            s -= l

    def blob(c, axis, rx, ry, rz, tilt):
        m = bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=1.0)
        q = axis.to_track_quat("Z", "Y")
        rot = q.to_matrix().to_4x4() @ Matrix.Rotation(tilt, 4, "Y") @ Matrix.Diagonal((rx, ry, rz, 1))
        bmesh.ops.transform(bm, matrix=Matrix.Translation(c) @ rot, verts=m["verts"])

    n = max(2, int(total / seg))
    for k in range(n):
        c, axis, r = at(total * (k + 0.5) / n)
        blob(c, axis, r * 0.95, r * 0.75, seg * 0.85, 0.45 if k % 2 else -0.45)
    end, axis, r = at(total)
    blob(end + axis * 0.004, axis, r * 0.55, r * 0.55, 0.010, 0)                    # 고무줄
    blob(end + axis * 0.030, axis, r * 0.70, r * 0.55, 0.028, 0)                    # 끝 술
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    me.materials.append(mat)
    return bpy.data.objects.new(name, me)


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
