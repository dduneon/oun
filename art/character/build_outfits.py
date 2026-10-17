"""상점 의상(상의·하의·신발) 메시 생성기.

art/character/oun_villager.blend 를 연 Blender에서 실행한다.
  blender art/character/oun_villager.blend --background --python art/character/build_outfits.py

기본 반바지(CLOTH_SHORTS)·신발(SHOES)·티(CLOTH_TEE)·후드(CLOTH_HOODIE)를 복제해 색을 바꾸거나
잘라 내고, 바짓가랑이·부츠목 같은 원통은 반지름이 변하는 커브로 붙인다. 컬렉션 이름이 곧
render_layers.py LAYERS의 보일 컬렉션이다. 다시 실행하면 같은 컬렉션을 비우고 새로 만든다.
"""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector


def srgb(hex_):
    """'#RRGGBB'(상점 아이템 colorHex) → 선형 RGB."""
    c = [int(hex_[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c)


LEG_X = 0.062  # 다리 중심(좌우 대칭)


def mat(name, hex_):
    """기본 티 머티리얼(툰 셰이더)을 복제해 색만 바꾼다."""
    m = bpy.data.materials.get(name) or bpy.data.materials["Cloth_Tee"].copy()
    m.name = name
    next(n for n in m.node_tree.nodes if n.type == "RGB").outputs[0].default_value = (*srgb(hex_), 1)
    return m


def collection(name):
    col = bpy.data.collections.get(name) or bpy.data.collections.new(name)
    if col.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(col)
    for old in list(col.objects):
        bpy.data.objects.remove(old)
    return col


def dup(src_name, name, col, materials, keep=None, scale=None, warp=None, trim=None, snap=None):
    """메시 오브젝트를 복제한다. materials: 원래 머티리얼 이름 → 새 머티리얼.
    keep(v) 가 False인 꼭짓점은 지운다(소매 자르기 등). snap(v)는 잘린 가장자리 꼭짓점을 옮겨
    계단처럼 들쭉날쭉한 자른 선을 매끈하게 편다. scale은 바운딩 박스 중심 기준 배율.
    warp(v) → 새 위치(월드 좌표)로 꼭짓점을 옮긴다(반바지를 늘려 긴바지로).
    trim=(머티리얼, 판정 함수(면 중심, bm))이면 판정에 걸린 면에 그 머티리얼(밑단 띠)."""
    src = bpy.data.objects[src_name]
    me = src.data.copy()
    me.name = name
    if keep or scale or warp or trim:
        bm = bmesh.new()
        bm.from_mesh(me)
        mw = src.matrix_world
        if keep:
            bmesh.ops.delete(bm, geom=[v for v in bm.verts if not keep(mw @ v.co)], context="VERTS")
            if snap:
                inv = mw.inverted()
                for v in bm.verts:
                    if v.is_boundary:
                        v.co = inv @ snap(mw @ v.co)
        if trim:
            me.materials.append(trim[0])
            pick = trim[1](bm, mw)
            for f in bm.faces:
                if pick(mw @ f.calc_center_median()):
                    f.material_index = len(me.materials) - 1
        if warp:
            inv = mw.inverted()
            for v in bm.verts:
                v.co = inv @ warp(mw @ v.co)
        if scale:
            c = sum((v.co for v in bm.verts), Vector()) / max(1, len(bm.verts))
            bmesh.ops.transform(bm, verts=bm.verts, matrix=Matrix.Translation(c) @ Matrix.Diagonal((*scale, 1))
                                @ Matrix.Translation(-c))
        bm.to_mesh(me)
        bm.free()
    for i, slot_mat in enumerate(me.materials):
        if slot_mat and slot_mat.name in materials:
            me.materials[i] = materials[slot_mat.name]
    ob = bpy.data.objects.new(name, me)
    ob.matrix_world = src.matrix_world
    for m in src.modifiers:
        nm = ob.modifiers.new(m.name, m.type)
        for attr in ("levels", "render_levels", "thickness", "offset", "use_rim", "factor", "iterations"):
            if hasattr(m, attr):
                setattr(nm, attr, getattr(m, attr))
    col.objects.link(ob)
    return ob


def tube(name, col, m, pts):
    """반지름이 변하는 매끈한 원통(바짓가랑이·부츠목). pts: (x, y, z, r)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth, cu.bevel_resolution, cu.resolution_u = 1.0, 8, 16
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    sp.points.add(len(pts) - 1)
    for p, (x, y, z, r) in zip(sp.points, pts):
        p.co, p.radius = (x, y, z, 1), r
    sp.use_endpoint_u, sp.order_u = True, min(4, len(pts))
    cu.materials.append(m)
    ob = bpy.data.objects.new(name, cu)
    col.objects.link(ob)
    return ob


def ring(name, col, m, center, radius, thickness, sy=1.0):
    """수평 도넛(밑단 띠·부츠 입구). sy로 앞뒤를 눌러 타원으로 만든다."""
    bm = bmesh.new()
    seg_major, seg_minor = 48, 10
    rings = []
    for i in range(seg_major):
        u = 2 * math.pi * i / seg_major
        rr = []
        for j in range(seg_minor):
            v = 2 * math.pi * j / seg_minor
            R = radius + thickness * math.cos(v)
            rr.append(bm.verts.new(Vector(center) + Vector((R * math.cos(u), R * math.sin(u) * sy,
                                                            thickness * math.sin(v)))))
        rings.append(rr)
    for i in range(seg_major):
        a, b = rings[i], rings[(i + 1) % seg_major]
        for j in range(seg_minor):
            bm.faces.new((a[j], b[j], b[(j + 1) % seg_minor], a[(j + 1) % seg_minor]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    col.objects.link(ob)
    return ob


def box(name, col, m, lo, hi):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    c = (Vector(lo) + Vector(hi)) / 2
    d = Vector(hi) - Vector(lo)
    bmesh.ops.transform(bm, verts=bm.verts, matrix=Matrix.Translation(c) @ Matrix.Diagonal((*d, 1)))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    col.objects.link(ob)
    return ob


def legs(col, m, pts):
    """좌우 다리에 같은 원통. pts: (z, r) 위→아래."""
    for side in (1, -1):
        tube(f"{col.name}_Leg{'L' if side < 0 else 'R'}", col, m, [(side * LEG_X, 0.0, z, r) for z, r in pts])


def shoes(col, upper, sole):
    for side in ("1", "-1"):
        dup(f"SHOES_{side}", f"{col.name}_Shoe{side}", col, {"Shoe": upper})
        dup(f"SHOES_sole_{side}", f"{col.name}_Sole{side}", col, {"Sole": sole})


# ── 하의 ──────────────────────────────────────────────────────────
# 기본 반바지는 가랑이 끝이 둥글게 닫힌 덩어리(밑단 z≈0.076)다. 긴바지는 반바지가 가장 넓은
# 곳(z≈0.14, 반지름≈0.054)에서 같은 굵기로 이어지는 원통을 붙여, 이음매가 보이지 않게 한다.
HEM_X = 0.064


def pant_legs(col, m, pts):
    for side in (1, -1):
        tube(f"{col.name}_Leg{'L' if side < 0 else 'R'}", col, m, [(side * HEM_X, 0.0, z, r) for z, r in pts])


def bottom_jogger():
    """조거 트레이닝 바지: 발목까지 내려와 오므라든 바짓가랑이 + 고무 밑단."""
    col = collection("BOTTOM_JOGGER")
    m, cuff = mat("Jogger_Gray", "#8E96A3"), mat("Jogger_Cuff", "#6E7682")
    dup("CLOTH_SHORTS", "JoggerHips", col, {"Cloth_Shorts": m})
    pant_legs(col, m, [(0.135, 0.0525), (0.110, 0.0525), (0.085, 0.051), (0.072, 0.049)])
    pant_legs(col, cuff, [(0.078, 0.0485), (0.066, 0.0495), (0.054, 0.0485)])


def bottom_running_shorts():
    """러닝 쇼츠: 반바지 가랑이 끝에 흰 밑단 띠."""
    col = collection("BOTTOM_RUNSHORTS")
    dup("CLOTH_SHORTS", "RunShorts", col, {"Cloth_Shorts": mat("RunShorts_Coral", "#E8836B")})
    for side in (1, -1):
        ring(f"RunShortsHem{side}", col, mat("RunShorts_Trim", "#FFF6EC"),
             (side * HEM_X, 0.0, 0.101), 0.0470, 0.0060)


def bottom_leggings():
    """레깅스: 다리에 붙는 발목 길이."""
    col = collection("BOTTOM_LEGGINGS")
    m = mat("Leggings_Charcoal", "#4A4550")
    dup("CLOTH_SHORTS", "LeggingsHips", col, {"Cloth_Shorts": m})
    pant_legs(col, m, [(0.135, 0.0525), (0.105, 0.0505), (0.080, 0.0490), (0.060, 0.0480)])


# ── 신발 ──────────────────────────────────────────────────────────
def shoes_running():
    col = collection("SHOES_RUNNING")
    shoes(col, mat("RunShoe_Mint", "#7FC8B4"), mat("RunShoe_Sole", "#FFFDF8"))


def shoes_hightop():
    """하이탑 스니커즈: 발목을 덮는 목."""
    col = collection("SHOES_HIGHTOP")
    up, sole = mat("Hightop_Red", "#D9574A"), mat("Hightop_Sole", "#FFF6EC")
    shoes(col, up, sole)
    for side in (1, -1):
        tube(f"HightopCollar{side}", col, up, [(side * LEG_X, -0.004, z, r) for z, r in
                                               [(0.030, 0.049), (0.070, 0.050), (0.096, 0.051)]])
        ring(f"HightopRim{side}", col, sole, (side * LEG_X, -0.004, 0.096), 0.050, 0.006)


def shoes_rainboots():
    """레인부츠: 정강이까지 올라오는 노란 장화."""
    col = collection("SHOES_RAINBOOTS")
    up, sole = mat("Boots_Yellow", "#F2C14E"), mat("Boots_Sole", "#7A5A3A")
    shoes(col, up, sole)
    for side in (1, -1):
        tube(f"BootsShaft{side}", col, up, [(side * LEG_X, -0.004, z, r) for z, r in
                                            [(0.030, 0.051), (0.080, 0.052), (0.118, 0.055)]])
        ring(f"BootsRim{side}", col, up, (side * LEG_X, -0.004, 0.118), 0.055, 0.006)


# ── 상의 ──────────────────────────────────────────────────────────
def top_tank():
    """민소매 탱크톱: 티에서 소매를 잘라 낸다."""
    col = collection("TOP_TANK")
    dup("CLOTH_TEE", "Tank", col, {"Cloth_Tee": mat("Tank_Sky", "#8FC1E3")},
        keep=lambda v: abs(v.x) < armhole(v.z), snap=snap_armhole)


def snap_armhole(v):
    lim = armhole(v.z)
    if abs(v.x) < lim - 0.012:  # 목둘레·밑단은 원래 가장자리 그대로
        return v
    return Vector((math.copysign(lim, v.x), v.y, v.z))


def armhole(z):
    """탱크톱 진동 둘레: 옆구리는 몸통 폭, 위로 갈수록 둥글게 파여 어깨에 가는 끈만 남는다."""
    t = max(0.0, min(1.0, (z - 0.28) / 0.13))
    return 0.128 - 0.052 * (1 - math.sqrt(1 - t * t))  # 원호처럼 위에서 급하게 파인다


def top_windbreaker():
    """바람막이 집업: 후드를 청록색으로 바꾸고 앞섶에 지퍼."""
    col = collection("TOP_WINDBREAKER")
    main, trim = mat("Wind_Teal", "#3F7F8C"), mat("Wind_Trim", "#F3EBDD")
    swap = {"Hoodie_Tan": main, "Hoodie_Cream": trim, "Hoodie_Pocket": main}
    for o in bpy.data.collections["CLOTH_HOODIE"].objects:
        if o.type == "MESH":
            dup(o.name, f"Wind_{o.name}", col, swap)
    box("WindZip", col, trim, (-0.005, -0.127, 0.195), (0.005, -0.117, 0.40))


def main():
    for build in (bottom_jogger, bottom_running_shorts, bottom_leggings,
                  shoes_running, shoes_hightop, shoes_rainboots, top_tank, top_windbreaker):
        build()


main()
