"""오운 캐릭터 레이어 렌더러.

art/character/oun_villager.blend 를 연 Blender에서 실행한다.
  blender art/character/oun_villager.blend --background --python art/character/render_layers.py

모든 레이어를 같은 정사영 카메라·같은 캔버스로 렌더해서 Flutter가 그대로 겹쳐 그린다.
가려져야 하는 부분(예: 머리 뒤로 넘어간 포니테일, 몸 뒤쪽 후드)은 BODY를 홀드아웃으로
렌더해 미리 투명하게 뚫어 둔다. 레이어 순서는 Flutter(CharacterAvatar)가 정한다:
  몸 → 상의 → 타월 → 머리 → 이어폰 → 모자
여자는 같은 몸에 얼굴 텍스처만 다른 body_f* 를 쓴다.
"""

from pathlib import Path

import bpy
import numpy as np

ROOT = Path(bpy.data.filepath).resolve().parents[2]
OUT = ROOT / "app" / "assets" / "character"
FACE_TEX = ROOT / "art" / "character" / "face_default.png"

W, H = 800, 1000

# 파일 이름 → (보일 컬렉션, 홀드아웃 컬렉션)
LAYERS = {
    "body": (["BODY", "CLOTH_SHORTS", "SHOES"], []),
    "top_basic": (["CLOTH_TEE"], ["BODY"]),
    "top_hood_daily": (["CLOTH_HOODIE"], ["BODY"]),
    "top_tee_runner": (["CLOTH_RUNNER"], ["BODY"]),
    "top_cardigan_knit": (["CLOTH_CARDIGAN"], ["BODY"]),
    # 헤어 메시는 build_hair.py 가 만든다. 성별 기본 머리: 남자 short, 여자 down.
    "hair_short": (["HAIR_AC_SHORT"], ["BODY", "CLOTH_TEE"]),
    "hair_down": (["HAIR_AC_DOWN"], ["BODY", "CLOTH_TEE"]),
    # 모자를 쓸 때: 챙 위쪽 머리를 눌러 모자 밖으로 삐져나오지 않게 한 변형.
    "hair_short_cap": (["HAIR_AC_SHORT_CAP"], ["BODY", "CLOTH_TEE", "PROP_CAP"]),
    "hair_down_cap": (["HAIR_AC_DOWN_CAP"], ["BODY", "CLOTH_TEE", "PROP_CAP"]),
    "prop_towel_gym": (["PROP_TOWEL"], ["BODY"]),
    "prop_earbuds": (["PROP_EARBUDS"], ["BODY"]),
    "prop_cap_sports": (["PROP_CAP"], ["BODY"]),
}

# 표정 변형: 몸 레이어만 얼굴 텍스처를 바꿔 다시 렌더한다.
FACES = {
    "body": dict(),
    "body_blink": dict(closed=True),
    "body_happy": dict(closed=True, mouth="open"),
}
# 여자 얼굴: 속눈썹, 조금 진한 볼터치, 붉은 입.
FEMALE = dict(lashes=True, blush=0.85, lip=(0.68, 0.22, 0.24))
FACES.update({f"body_f{k[4:]}": {**v, **FEMALE} for k, v in list(FACES.items())})


def draw_face(eye_rx=0.031, eye_rz=0.040, eye_x=0.115, eye_z=0.682, mouth="smile", closed=False,
              lashes=False, blush=0.6, lip=(0.50, 0.18, 0.16)):
    """머리 정면 투영 좌표(x: -0.33..0.33, z: 0.37..1.03)에 얼굴을 그린 RGBA 배열."""
    n, ss = 1024, 2
    m = n * ss
    x0, z0, span = -0.33, 0.37, 0.66
    xs = x0 + (np.arange(m) + 0.5) / m * span
    zs = z0 + (np.arange(m) + 0.5) / m * span
    X, Z = np.meshgrid(xs, zs)
    img = np.zeros((m, m, 4), np.float32)
    px = span / m

    def over(alpha, rgb):
        a = np.clip(alpha, 0, 1)[..., None]
        img[..., :3] = img[..., :3] * (1 - a) + np.array(rgb, np.float32) * a
        img[..., 3:] = img[..., 3:] * (1 - a) + a

    def ellipse(cx, cz, rx, rz, rot=0.0):
        c, s = np.cos(rot), np.sin(rot)
        dx, dz = X - cx, Z - cz
        u = (dx * c + dz * s) / rx
        v = (-dx * s + dz * c) / rz
        d = (np.sqrt(u * u + v * v) - 1) * min(rx, rz)
        return np.clip(0.5 - d / (px * 1.5), 0, 1)

    def polyline(pts, w):
        d = np.full(X.shape, 9.0)
        for (ax, az), (bx, bz) in zip(pts[:-1], pts[1:]):
            vx, vz = bx - ax, bz - az
            t = np.clip(((X - ax) * vx + (Z - az) * vz) / (vx * vx + vz * vz), 0, 1)
            d = np.minimum(d, np.hypot(X - (ax + t * vx), Z - (az + t * vz)))
        return np.clip(0.5 - (d - w) / (px * 1.5), 0, 1)

    def soft(cx, cz, rx, rz):
        u = (X - cx) / rx
        v = (Z - cz) / rz
        return np.clip(1 - (u * u + v * v), 0, 1) ** 1.6

    dark = (0.10, 0.065, 0.055)
    for s in (-1, 1):
        ex = s * eye_x
        over(soft(s * 0.192, eye_z - 0.055, 0.038, 0.022) * blush, (1.0, 0.50, 0.50))  # 볼터치
        if closed:
            # 웃는 눈(∩)
            arc = [(ex + t * eye_rx, eye_z - 0.006 + 0.012 * (1 - t * t)) for t in np.linspace(-1, 1, 13)]
            over(polyline(arc, 0.0034), dark)
            if lashes:
                over(polyline([(ex + s * eye_rx, eye_z - 0.006), (ex + s * 1.4 * eye_rx, eye_z + 0.003)], 0.0028), dark)
        else:
            if lashes:
                # 눈꼬리 위로 뻗는 속눈썹 두 가닥
                for (u0, v0), (u1, v1) in (((0.60, 0.72), (1.02, 1.08)), ((0.86, 0.42), (1.32, 0.66))):
                    over(polyline([(ex + s * u0 * eye_rx, eye_z + v0 * eye_rz),
                                   (ex + s * u1 * eye_rx, eye_z + v1 * eye_rz)], 0.0030), dark)
            e = ellipse(ex, eye_z, eye_rx, eye_rz)
            over(e, dark)
            over(e * np.clip((eye_z - Z) / eye_rz + 0.15, 0, 1) * 0.5, (0.36, 0.21, 0.13))
            over(ellipse(ex - 0.32 * eye_rx, eye_z + 0.36 * eye_rz, 0.36 * eye_rx, 0.3 * eye_rz), (1, 1, 1))
            over(ellipse(ex + 0.3 * eye_rx, eye_z - 0.42 * eye_rz, 0.14 * eye_rx, 0.11 * eye_rz), (1, 1, 1))
        over(ellipse(ex + s * 0.003, eye_z + eye_rz + 0.024, 0.017, 0.005, rot=-0.18 * s), (0.30, 0.19, 0.13))
    if mouth == "smile":
        pts = [(x, 0.590 + 0.011 * (x / 0.024) ** 2) for x in np.linspace(-0.024, 0.024, 13)]
        over(polyline(pts, 0.0028), lip)
    else:  # 활짝 웃는 입(D)
        lower = ellipse(0, 0.593, 0.026, 0.024) * (Z < 0.593)
        over(lower, (0.55, 0.20, 0.20))
        over(ellipse(0, 0.578, 0.014, 0.008) * lower, (0.96, 0.56, 0.56))
    out = img.reshape(n, ss, n, ss, 4).mean(axis=(1, 3))
    # 머티리얼은 straight alpha로 읽으므로 프리멀티플라이를 푼다.
    a = out[..., 3:4]
    out[..., :3] = np.where(a > 1e-4, out[..., :3] / np.maximum(a, 1e-4), 0)
    return out


def set_face(**kwargs):
    img = bpy.data.images["FaceTex"]
    img.pixels.foreach_set(draw_face(**kwargs).ravel())
    img.update()


def show_only(visible, holdout):
    for lc in bpy.context.view_layer.layer_collection.children:
        name = lc.collection.name
        lc.exclude = name not in visible and name not in holdout
        lc.holdout = name in holdout
        lc.collection.hide_render = False


def render(name):
    scene = bpy.context.scene
    scene.render.filepath = str(OUT / f"{name}.png")
    bpy.ops.render.render(write_still=True)


def main():
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = W, H
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.compression = 90
    OUT.mkdir(parents=True, exist_ok=True)

    for name, (visible, holdout) in LAYERS.items():
        show_only(visible, holdout)
        if name == "body":
            for face_name, face in FACES.items():
                set_face(**face)
                render(face_name)
            set_face()
        else:
            render(name)

    # 편집 상태로 되돌린다(기본 차림: 짧은 머리 + 기본 티).
    show_only(["BODY", "CLOTH_SHORTS", "SHOES", "CLOTH_TEE", "HAIR_AC_SHORT"], [])


main()
