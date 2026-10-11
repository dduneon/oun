using UnityEngine;
using UnityEngine.Rendering;
using System.Collections.Generic;

/// <summary>
/// 상점 아이템(의상·헤어·소품)을 휴머노이드 캐릭터에 입히는 가벼운 런타임 장착기.
/// 캐릭터는 회색 바디슈트 + 갈색 헤어가 한 장의 텍스처에 칠해진 단일 스킨 메시라서
/// 의상/헤어는 ① 해당 색 영역을 런타임에 다시 칠하고 ② 후드·포니테일 같은 디테일을
/// 뼈에 덧붙인다. 디테일과 소품은 Blender에서 만든 FBX(Resources/Equipment)를 쓰고,
/// 붙일 위치는 몸 표면을 재서 정한다(남/여 체형 차이 대응).
/// </summary>
public class AvatarEquipment : MonoBehaviour
{
    const string RootName = "__OunEquipped_";

    enum Slot { Clothing, Hair, Prop }

    Animator animator;
    float avatarHeight = 1.7f;
    Vector3[] bakedVertices; // 현재 포즈의 스킨 메시 정점(월드 좌표). 표면 측정용.
    Bounds avatarBounds;
    readonly Dictionary<Slot, Transform> roots = new Dictionary<Slot, Transform>();
    readonly Dictionary<Slot, List<Material>> slotMaterials = new Dictionary<Slot, List<Material>>();
    Slot buildingSlot;

    // 텍스처 재칠하기 상태.
    SkinnedMeshRenderer bodyRenderer;
    Material bodyMaterial; // 이 캐릭터 전용 인스턴스(공유 머티리얼을 건드리지 않는다).
    Texture originalTexture;
    Texture2D tintedTexture;
    string appliedTint;

    // 원본 텍스처 픽셀은 같은 프리팹끼리 공유하므로 정적으로 캐시한다.
    static readonly Dictionary<Texture, Color32[]> sourcePixels = new Dictionary<Texture, Color32[]>();

    /// <summary>슬롯별 아이템을 한 번에 적용한다. null/빈 문자열은 해당 슬롯을 비운다.</summary>
    public string Apply(string clothingKey, string hairKey, string propKey)
    {
        clothingKey = Normalize(clothingKey);
        hairKey = Normalize(hairKey);
        propKey = Normalize(propKey);

        animator = GetComponentInChildren<Animator>(true);
        if (animator == null || !animator.isHuman)
        {
            Debug.LogWarning("휴머노이드 Animator가 없어 아이템을 장착할 수 없다: " + name);
            return "no_humanoid";
        }
        avatarHeight = MeasureAvatarHeight();
        bakedVertices = null; // 표면 측정은 디테일이 필요할 때 한 번만 굽는다.

        try
        {
            ApplyTint(ClothingColor(clothingKey), HairColor(hairKey));
        }
        catch (System.Exception e)
        {
            // 재칠하기에 실패해도 디테일·소품 장착은 계속한다.
            Debug.LogWarning("의상/헤어 색을 바꾸지 못했다: " + e);
        }

        var missing = new List<string>();
        if (!BuildSlot(Slot.Clothing, clothingKey)) missing.Add(clothingKey);
        if (!BuildSlot(Slot.Hair, hairKey)) missing.Add(hairKey);
        if (!BuildSlot(Slot.Prop, propKey)) missing.Add(propKey);
        return missing.Count == 0 ? "ok" : "missing=" + string.Join(",", missing);
    }

    public bool ApplyProp(string itemKey) => Apply(null, null, itemKey) == "ok";

    static string Normalize(string key) =>
        string.IsNullOrWhiteSpace(key) ? null : key.Trim().ToLowerInvariant();

    bool BuildSlot(Slot slot, string itemKey)
    {
        ClearSlot(slot);
        if (itemKey == null) return true;
        buildingSlot = slot;
        try
        {
            return BuildItem(slot, itemKey);
        }
        catch (System.Exception e)
        {
            // 한 슬롯이 실패해도 다른 슬롯 장착은 이어가고, 반쯤 만든 조각은 치운다.
            Debug.LogWarning("아이템을 장착하지 못했다: " + itemKey + " — " + e);
            ClearSlot(slot);
            return false;
        }
    }

    bool BuildItem(Slot slot, string itemKey)
    {
        switch (itemKey)
        {
            // 의상: 바디슈트 색은 ApplyTint가 바꾸고 여기선 디테일만 붙인다.
            case "hood_daily": BuildHood(); break;
            case "tee_runner": BuildRunnerBib(); break;
            case "cardigan_knit": BuildCardiganButtons(); break;
            // 헤어: 단발은 원래 헤어 모양 그대로 색만 바꾼다.
            case "hair_bob": return true;
            case "hair_ponytail": BuildPonytail(); break;
            case "hair_braids": BuildBraids(); break;
            // 소품
            case "cap_sports": BuildCap(); break;
            case "towel_gym": BuildTowel(); break;
            case "earbuds": BuildEarbuds(); break;
            default:
                Debug.Log("아직 3D 모델이 연결되지 않은 아이템: " + itemKey);
                return false;
        }
        return roots.ContainsKey(slot);
    }

    void ClearSlot(Slot slot)
    {
        if (roots.TryGetValue(slot, out var root) && root != null)
        {
            // Destroy는 프레임 끝에 처리되므로 같은 프레임에 새 아이템과 겹쳐 보이지 않게 먼저 숨긴다.
            root.gameObject.SetActive(false);
            Destroy(root.gameObject);
        }
        roots.Remove(slot);
        if (slotMaterials.TryGetValue(slot, out var list))
        {
            foreach (var material in list)
                if (material != null) Destroy(material);
            list.Clear();
        }
    }

    void OnDestroy()
    {
        foreach (Slot slot in System.Enum.GetValues(typeof(Slot))) ClearSlot(slot);
        if (tintedTexture != null) Destroy(tintedTexture);
        if (bodyMaterial != null) Destroy(bodyMaterial);
    }

    // ── 의상/헤어 색 ─────────────────────────────────────────────

    static Color? ClothingColor(string key)
    {
        switch (key)
        {
            case "hood_daily": return new Color(0.85f, 0.62f, 0.42f);
            case "tee_runner": return new Color(0.60f, 0.72f, 0.54f);
            case "cardigan_knit": return new Color(0.90f, 0.64f, 0.60f);
            default: return null;
        }
    }

    static Color? HairColor(string key)
    {
        switch (key)
        {
            case "hair_bob": return new Color(0.66f, 0.46f, 0.30f);
            case "hair_ponytail": return new Color(0.30f, 0.19f, 0.15f);
            case "hair_braids": return new Color(0.58f, 0.32f, 0.19f);
            default: return null;
        }
    }

    /// <summary>
    /// 원본 텍스처의 회색(바디슈트)·갈색(헤어) 영역을 지정 색으로 다시 칠한다.
    /// 원본 명암(밝기)을 곱해 주름·그늘은 유지하고, 경계는 가중치로 부드럽게 섞는다.
    /// </summary>
    void ApplyTint(Color? clothing, Color? hair)
    {
        string tint = (clothing.HasValue ? ColorUtility.ToHtmlStringRGB(clothing.Value) : "-") + "/"
            + (hair.HasValue ? ColorUtility.ToHtmlStringRGB(hair.Value) : "-");
        if (tint == appliedTint) return;

        if (bodyRenderer == null)
        {
            bodyRenderer = GetComponentInChildren<SkinnedMeshRenderer>(true);
            if (bodyRenderer == null) return;
            bodyMaterial = bodyRenderer.material; // 인스턴스 생성
            originalTexture = bodyMaterial.mainTexture;
        }
        if (originalTexture == null) return;
        appliedTint = tint;

        if (!clothing.HasValue && !hair.HasValue)
        {
            bodyMaterial.mainTexture = originalTexture;
            return;
        }

        var src = SourcePixels(originalTexture);
        var headMask = HeadMask(originalTexture.width, originalTexture.height);
        if (tintedTexture == null)
        {
            tintedTexture = new Texture2D(originalTexture.width, originalTexture.height,
                TextureFormat.RGBA32, true) { name = "Oun tinted body", wrapMode = originalTexture.wrapMode };
        }
        var dst = new Color32[src.Length];
        Color cloth = clothing ?? Color.clear;
        Color hairC = hair ?? Color.clear;
        for (int i = 0; i < src.Length; i++)
        {
            Color32 p = src[i];
            float r = p.r / 255f, g = p.g / 255f, b = p.b / 255f;
            float max = Mathf.Max(r, Mathf.Max(g, b));
            float min = Mathf.Min(r, Mathf.Min(g, b));
            float sat = max > 0.001f ? (max - min) / max : 0f;
            float outR = r, outG = g, outB = b;

            if (clothing.HasValue && (headMask == null || !headMask[i]))
            {
                // 바디슈트: 채도가 낮고 중간 밝기의 회색. 흰자(밝음)·눈동자/외곽선(어두움) 제외.
                float w = (1f - Smooth(0.18f, 0.25f, sat))
                    * Smooth(0.22f, 0.32f, max) * (1f - Smooth(0.78f, 0.86f, max));
                if (w > 0f)
                {
                    float shade = Mathf.Clamp(max / 0.56f, 0.55f, 1.25f);
                    outR = Mathf.Lerp(outR, cloth.r * shade, w);
                    outG = Mathf.Lerp(outG, cloth.g * shade, w);
                    outB = Mathf.Lerp(outB, cloth.b * shade, w);
                }
            }
            if (hair.HasValue && r > b)
            {
                // 헤어: 붉은 기의 중간 어두운 갈색. 피부(밝음)·코(주황, 밝음)·눈동자(아주 어두움) 제외.
                float hue = Hue(r, g, b, max, min);
                float w = Smooth(0.22f, 0.32f, sat) * Smooth(0.24f, 0.32f, max)
                    * (1f - Smooth(0.58f, 0.68f, max)) * (1f - Smooth(40f, 55f, hue));
                if (w > 0f)
                {
                    float shade = Mathf.Clamp(max / 0.42f, 0.6f, 1.3f);
                    outR = Mathf.Lerp(outR, hairC.r * shade, w);
                    outG = Mathf.Lerp(outG, hairC.g * shade, w);
                    outB = Mathf.Lerp(outB, hairC.b * shade, w);
                }
            }
            dst[i] = new Color32((byte)(Mathf.Clamp01(outR) * 255f), (byte)(Mathf.Clamp01(outG) * 255f),
                (byte)(Mathf.Clamp01(outB) * 255f), p.a);
        }
        tintedTexture.SetPixels32(dst);
        tintedTexture.Apply(true, false);
        bodyMaterial.mainTexture = tintedTexture;
    }

    // 메시별 "머리 뼈에 붙은 삼각형이 차지하는 텍스처 영역" 마스크 캐시.
    static readonly Dictionary<Mesh, bool[]> headMasks = new Dictionary<Mesh, bool[]>();

    /// <summary>
    /// 흰자 음영도 채도 낮은 회색이라 색만으로는 바디슈트와 구분되지 않는다.
    /// 머리 뼈 가중치가 큰 삼각형을 UV 공간에 래스터화해 옷 재칠하기에서 제외한다.
    /// 메시를 읽을 수 없으면 null(마스크 없이 색 기준만 사용).
    /// </summary>
    bool[] HeadMask(int width, int height)
    {
        var mesh = bodyRenderer.sharedMesh;
        if (mesh == null || !mesh.isReadable) return null;
        if (headMasks.TryGetValue(mesh, out var cached) && cached.Length == width * height) return cached;

        var head = animator.GetBoneTransform(HumanBodyBones.Head);
        int headIndex = System.Array.IndexOf(bodyRenderer.bones, head);
        if (headIndex < 0) return null;

        var weights = mesh.boneWeights;
        var uvs = mesh.uv;
        var triangles = mesh.triangles;
        if (weights.Length == 0 || uvs.Length == 0) return null;
        var onHead = new bool[weights.Length];
        for (int i = 0; i < weights.Length; i++)
            onHead[i] = weights[i].boneIndex0 == headIndex && weights[i].weight0 >= 0.5f;

        var mask = new bool[width * height];
        for (int t = 0; t < triangles.Length; t += 3)
        {
            int a = triangles[t], b = triangles[t + 1], c = triangles[t + 2];
            if (!onHead[a] || !onHead[b] || !onHead[c]) continue;
            RasterizeUv(mask, width, height, uvs[a], uvs[b], uvs[c]);
        }
        headMasks[mesh] = mask;
        return mask;
    }

    static void RasterizeUv(bool[] mask, int width, int height, Vector2 uvA, Vector2 uvB, Vector2 uvC)
    {
        Vector2 a = new Vector2(uvA.x * width, uvA.y * height);
        Vector2 b = new Vector2(uvB.x * width, uvB.y * height);
        Vector2 c = new Vector2(uvC.x * width, uvC.y * height);
        // 경계 픽셀의 번짐까지 덮도록 1px 넓혀 잡는다.
        int minX = Mathf.Clamp(Mathf.FloorToInt(Mathf.Min(a.x, Mathf.Min(b.x, c.x))) - 1, 0, width - 1);
        int maxX = Mathf.Clamp(Mathf.CeilToInt(Mathf.Max(a.x, Mathf.Max(b.x, c.x))) + 1, 0, width - 1);
        int minY = Mathf.Clamp(Mathf.FloorToInt(Mathf.Min(a.y, Mathf.Min(b.y, c.y))) - 1, 0, height - 1);
        int maxY = Mathf.Clamp(Mathf.CeilToInt(Mathf.Max(a.y, Mathf.Max(b.y, c.y))) + 1, 0, height - 1);
        float area = (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y);
        if (Mathf.Abs(area) < 1e-6f)
        {
            mask[minY * width + minX] = true;
            return;
        }
        // 바리센트릭 좌표가 -eps까지면 변에서 약 1px 바깥까지 포함한다(eps ≈ 1px / 높이).
        float maxEdge = Mathf.Max((b - a).magnitude, Mathf.Max((c - b).magnitude, (a - c).magnitude));
        float eps = 1.2f * maxEdge / Mathf.Abs(area);
        for (int y = minY; y <= maxY; y++)
        {
            for (int x = minX; x <= maxX; x++)
            {
                Vector2 p = new Vector2(x + 0.5f, y + 0.5f);
                float w0 = ((b.x - p.x) * (c.y - p.y) - (c.x - p.x) * (b.y - p.y)) / area;
                float w1 = ((c.x - p.x) * (a.y - p.y) - (a.x - p.x) * (c.y - p.y)) / area;
                float w2 = 1f - w0 - w1;
                if (w0 >= -eps && w1 >= -eps && w2 >= -eps) mask[y * width + x] = true;
            }
        }
    }

    static float Smooth(float edge0, float edge1, float x)
    {
        float t = Mathf.Clamp01((x - edge0) / (edge1 - edge0));
        return t * t * (3f - 2f * t);
    }

    static float Hue(float r, float g, float b, float max, float min)
    {
        float d = max - min;
        if (d < 0.0001f) return 0f;
        float h;
        if (max == r) h = (g - b) / d;
        else if (max == g) h = 2f + (b - r) / d;
        else h = 4f + (r - g) / d;
        h *= 60f;
        return h < 0f ? h + 360f : h;
    }

    /// <summary>
    /// 임포트 설정상 텍스처가 Read/Write 비활성(GPU 전용)이어도 읽을 수 있도록
    /// RenderTexture로 복사한 뒤 CPU로 읽는다. 결과는 원본 텍스처별로 캐시.
    /// </summary>
    static Color32[] SourcePixels(Texture texture)
    {
        if (sourcePixels.TryGetValue(texture, out var cached)) return cached;
        var rt = RenderTexture.GetTemporary(texture.width, texture.height, 0,
            RenderTextureFormat.ARGB32, RenderTextureReadWrite.sRGB);
        var previous = RenderTexture.active;
        Graphics.Blit(texture, rt);
        RenderTexture.active = rt;
        var readable = new Texture2D(texture.width, texture.height, TextureFormat.RGBA32, false);
        readable.ReadPixels(new Rect(0, 0, texture.width, texture.height), 0, 0);
        readable.Apply(false, false);
        RenderTexture.active = previous;
        RenderTexture.ReleaseTemporary(rt);
        var pixels = readable.GetPixels32();
        Destroy(readable);
        sourcePixels[texture] = pixels;
        return pixels;
    }

    float MeasureAvatarHeight()
    {
        // 런타임 소품 Renderer는 제외하고 원래 스킨 메시만 재서, 소품을 연속으로
        // 갈아 끼우는 같은 프레임에도 기준 키가 커지지 않게 한다.
        var renderers = GetComponentsInChildren<SkinnedMeshRenderer>(true);
        if (renderers.Length == 0) return 1.7f;

        avatarBounds = renderers[0].bounds;
        for (int i = 1; i < renderers.Length; i++)
            avatarBounds.Encapsulate(renderers[i].bounds);
        return Mathf.Clamp(avatarBounds.size.y, 1.2f, 2.2f);
    }

    Transform NewRoot(Transform bone)
    {
        var root = new GameObject(RootName);
        root.layer = gameObject.layer;
        root.transform.SetParent(transform, false);
        root.transform.position = bone.position;
        root.transform.rotation = transform.rotation;
        // 뼈 아래로 다시 붙이되 월드 크기/방향은 유지한다. Mixamo 뼈의 축 방향과
        // import scale이 캐릭터마다 조금 달라도 소품 배치가 안정적이다.
        root.transform.SetParent(bone, true);
        root.name = RootName + buildingSlot;
        roots[buildingSlot] = root.transform;
        return root.transform;
    }

    Vector3 TowardCamera(Transform anchor)
    {
        // 프리팹마다 transform.forward가 실제 얼굴 방향과 반대일 수 있다.
        // 홈 카메라 쪽 수평 벡터를 쓰면 남/여 모델과 임포트 축에 상관없이
        // 소품이 몸 뒤가 아닌 사용자에게 보이는 앞면에 배치된다.
        var camera = Camera.main;
        if (camera != null)
        {
            var direction = Vector3.ProjectOnPlane(
                camera.transform.position - anchor.position, transform.up);
            if (direction.sqrMagnitude > 0.0001f) return direction.normalized;
        }
        return -transform.forward;
    }

    Transform Chest()
    {
        var chest = animator.GetBoneTransform(HumanBodyBones.UpperChest);
        if (chest == null) chest = animator.GetBoneTransform(HumanBodyBones.Chest);
        return chest;
    }

    /// <summary>
    /// origin에서 direction 쪽으로 몸 표면(가장 바깥 정점)까지의 거리.
    /// 남/여 캐릭터의 체형·헤어 크기가 달라 고정 오프셋으로는 디테일이 몸에 묻히거나
    /// 떠 보이므로, 현재 포즈를 구운 메시에서 직선 주변(radius) 정점만 보고 잰다.
    /// 스폰 직후 T포즈로 구워질 수 있어 maxRatio(avatarHeight 비율)보다 먼 정점
    /// (벌린 팔 등)은 무시한다.
    /// </summary>
    float SurfaceDistance(Vector3 origin, Vector3 direction, float radius, float fallback,
        float maxRatio = 0.25f)
    {
        if (bakedVertices == null)
        {
            var renderer = GetComponentInChildren<SkinnedMeshRenderer>(true);
            // 플레이어 빌드에서는 Read/Write가 꺼진 메시를 CPU로 읽을 수 없다
            // (에디터에서는 허용돼 차이가 숨는다). avatar.fbx 임포트 설정에서 켜 두었고,
            // 그래도 못 읽으면 예외 대신 고정 오프셋으로 물러난다.
            if (renderer == null || renderer.sharedMesh == null || !renderer.sharedMesh.isReadable)
            {
                bakedVertices = new Vector3[0];
            }
            else
            {
                var mesh = new Mesh();
                renderer.BakeMesh(mesh, true);
                var local = mesh.vertices;
                Destroy(mesh);
                var matrix = renderer.transform.localToWorldMatrix;
                bakedVertices = new Vector3[local.Length];
                for (int i = 0; i < local.Length; i++) bakedVertices[i] = matrix.MultiplyPoint3x4(local[i]);
            }
        }

        direction.Normalize();
        float best = -1f, radiusSq = radius * radius, max = avatarHeight * maxRatio;
        foreach (var vertex in bakedVertices)
        {
            Vector3 offset = vertex - origin;
            float along = Vector3.Dot(offset, direction);
            if (along <= best || along > max) continue;
            if ((offset - direction * along).sqrMagnitude <= radiusSq) best = along;
        }
        return best > 0f ? best : fallback;
    }

    // ── 장착 모델 ─────────────────────────────────────────────
    // Blender(Assets/Models/Accessories/oun_accessories_source.blend)에서 이 캐릭터 실측
    // (키 ≈1.06m)에 맞춰 만든 FBX를 Resources/Equipment에서 불러온다.
    // 모델 규칙: 원점 = 붙일 지점, 로컬 +Z = 앞, +Y = 위. 좌우가 있는 모델(이어폰·포니테일·
    // 브레이드)은 로컬 -X가 바깥쪽이다(Blender +X가 FBX 임포트에서 Unity -X가 된다).
    const float ReferenceHeight = 1.06f;

    float ModelScale => Mathf.Max(0.1f, avatarBounds.size.y / ReferenceHeight);

    /// <summary>모델을 position에 forward/up 방향으로 세우고, outward가 있으면 그쪽으로 좌우를 맞춘다.</summary>
    GameObject PlaceModel(string key, Transform root, Vector3 position, Vector3 forward, Vector3 up,
        Vector3? outward = null, Color? hairColor = null)
    {
        var model = InstantiateEquipmentModel("Equipment/" + key, hairColor);
        model.transform.rotation = Quaternion.LookRotation(forward, up);
        var scale = Vector3.one * ModelScale;
        // 바깥쪽이 반대면 X만 뒤집어 거울상으로 쓴다(왼쪽 이어폰·브레이드 등).
        if (outward.HasValue && Vector3.Dot(-model.transform.right, outward.Value) < 0f) scale.x = -scale.x;
        model.transform.localScale = scale;
        model.transform.position = position;
        model.transform.SetParent(root, true);
        return model;
    }

    void BuildHood()
    {
        var chest = Chest();
        var neck = animator.GetBoneTransform(HumanBodyBones.Neck);
        if (chest == null || neck == null) return;
        var root = NewRoot(chest);
        Vector3 up = transform.up;
        Vector3 forward = TowardCamera(chest);

        // 목에 두른 후드 테두리 + 등 뒤로 접힌 후드.
        PlaceModel("hood_daily", root, neck.position - up * (avatarHeight * 0.012f), forward, up);
        // 앞가슴 양쪽으로 늘어진 끈. 끈 모델 원점(윗 끝)을 몸 표면에 붙인다.
        for (int side = -1; side <= 1; side += 2)
        {
            Vector3 axis = chest.position + transform.right * (avatarHeight * 0.03f * side)
                + up * (avatarHeight * 0.005f);
            float depth = SurfaceDistance(axis, forward, avatarHeight * 0.015f, avatarHeight * 0.08f);
            PlaceModel("hood_string", root, axis + forward * (depth + avatarHeight * 0.003f), forward, up);
        }
    }

    void BuildRunnerBib()
    {
        var chest = Chest();
        if (chest == null) return;
        var root = NewRoot(chest);
        Vector3 forward = TowardCamera(chest);

        // 러닝 대회 배번표. 판 위·아래 끝의 몸 표면을 재서 둥근 배를 따라 기울이고,
        // 몸과 교차해 깜빡이지 않도록 표면에서 충분히 띄운다(모델 자체도 가로로 휘어 있다).
        float half = 0.045f * ModelScale;
        Vector3 axis = chest.position - transform.up * (avatarHeight * 0.045f);
        float radius = avatarHeight * 0.05f;
        Vector3 top = axis + transform.up * half;
        Vector3 bottom = axis - transform.up * half;
        top += forward * SurfaceDistance(top, forward, radius, avatarHeight * 0.08f);
        bottom += forward * SurfaceDistance(bottom, forward, radius, avatarHeight * 0.09f);
        Vector3 plateUp = (top - bottom).normalized;
        Vector3 plateNormal = Vector3.Cross(Vector3.Cross(plateUp, forward), plateUp).normalized;
        if (Vector3.Dot(plateNormal, forward) < 0f) plateNormal = -plateNormal;
        PlaceModel("bib_runner", root, (top + bottom) * 0.5f + plateNormal * (avatarHeight * 0.012f),
            plateNormal, plateUp);
    }

    void BuildCardiganButtons()
    {
        var chest = Chest();
        if (chest == null) return;
        var root = NewRoot(chest);
        Vector3 forward = TowardCamera(chest);

        // 앞섶 단추 세 개. 각 높이에서 몸 표면을 재서 단추 뒷면을 붙인다.
        for (int i = 0; i < 3; i++)
        {
            Vector3 axis = chest.position - transform.up * (avatarHeight * 0.045f * i);
            float depth = SurfaceDistance(axis, forward, avatarHeight * 0.015f, avatarHeight * 0.08f);
            PlaceModel("button_knit", root, axis + forward * (depth + avatarHeight * 0.002f), forward, transform.up);
        }
    }

    void BuildPonytail()
    {
        var head = animator.GetBoneTransform(HumanBodyBones.Head);
        if (head == null) return;
        var root = NewRoot(head);
        Vector3 up = transform.up;
        Vector3 side = transform.right;

        // 정면 카메라에서 잘 보이도록 옆으로 묶은 사이드 포니테일. 헤어 옆면에 묶는다.
        Vector3 axis = head.position + up * (avatarHeight * 0.147f);
        Vector3 knot = axis + side * (SurfaceDistance(axis, side, avatarHeight * 0.03f, avatarHeight * 0.2f)
            - avatarHeight * 0.006f);
        PlaceModel("hair_ponytail", root, knot, TowardCamera(head), up, side, HairColor("hair_ponytail"));
    }

    void BuildBraids()
    {
        var head = animator.GetBoneTransform(HumanBodyBones.Head);
        if (head == null) return;
        var root = NewRoot(head);
        Vector3 up = transform.up;
        Vector3 forward = TowardCamera(head);

        // 단발 끝에서 어깨 앞으로 내려오는 양갈래 땋은 머리.
        for (int side = -1; side <= 1; side += 2)
        {
            // 머리 옆 헤어 끝보다 조금 안쪽에서 시작해 어깨 위로 늘어뜨린다.
            Vector3 axis = head.position - up * (avatarHeight * 0.02f) + forward * (avatarHeight * 0.035f);
            Vector3 outward = transform.right * side;
            float width = SurfaceDistance(axis, outward, avatarHeight * 0.03f, avatarHeight * 0.2f);
            PlaceModel("hair_braid", root, axis + outward * (width * 0.82f), forward, up, outward,
                HairColor("hair_braids"));
        }
    }

    const float CapTiltDegrees = 9f;

    void BuildCap()
    {
        var head = animator.GetBoneTransform(HumanBodyBones.Head);
        if (head == null) return;
        var root = NewRoot(head);
        Vector3 up = transform.up;
        Vector3 forward = TowardCamera(head);
        var model = InstantiateEquipmentModel("Equipment/cap_sports", null);
        model.transform.SetParent(root, true);

        // Blender에서 제작한 캡의 로컬 +Z(챙)를 얼굴/카메라 쪽으로 맞추고, 뒤로 살짝 젖혀
        // 위에서 내려다보는 홈 카메라에서도 챙이 눈을 가리지 않게 한다.
        model.transform.rotation = Quaternion.LookRotation(forward, up) * Quaternion.Euler(-CapTiltDegrees, 0f, 0f);
        // 이 캐릭터는 머리가 커서 고정 크기로는 정수리에 얹힌 작은 모자가 된다.
        // 모자 밑단 높이에서 머리(헤어 포함) 폭을 재서 그보다 살짝 크게 맞추고,
        // 밑단을 이마 위쪽에 고정해 크라운이 정수리를 덮게 한다.
        float headToTop = Mathf.Max(avatarHeight * 0.12f, avatarBounds.max.y - head.position.y);
        Vector3 rim = head.position + up * (headToTop * 0.6f);
        float halfWidth = SurfaceDistance(rim, transform.right, avatarHeight * 0.03f, avatarHeight * 0.17f, 0.3f);
        // 챙까지 포함한 bounds로 맞추면 중심이 앞으로 쏠려 크라운이 뒤로 밀린다.
        // 크라운 메시만 기준으로 크기와 밑단 중앙을 잡는다.
        var crown = FindRenderer(model, "Crown");
        float crownWidth = crown.bounds.size.x;
        if (crownWidth > 0.0001f) model.transform.localScale *= halfWidth * 2f * 1.08f / crownWidth;
        Bounds crownBounds = crown.bounds;
        Vector3 crownBottom = new Vector3(crownBounds.center.x, crownBounds.min.y, crownBounds.center.z);
        model.transform.position += rim - up * (headToTop * 0.03f) - crownBottom;
    }

    static Renderer FindRenderer(GameObject model, string nameContains)
    {
        foreach (var renderer in model.GetComponentsInChildren<Renderer>(true))
            if (renderer.name.Contains(nameContains)) return renderer;
        throw new System.InvalidOperationException(model.name + "에 " + nameContains + " 메시가 없다");
    }

    void BuildTowel()
    {
        var chest = Chest();
        var neck = animator.GetBoneTransform(HumanBodyBones.Neck);
        if (chest == null || neck == null) return;
        var root = NewRoot(chest);
        Vector3 up = transform.up;
        Vector3 forward = TowardCamera(chest);

        // 목 뒤로 감아 양 끝이 가슴 앞으로 늘어진 타월. 모델은 기준 캐릭터의 가슴 앞면
        // (목 뼈에서 앞으로 ≈0.096m)에 맞춰져 있어, 가슴이 더 나온 체형이면 그만큼 앞으로 민다.
        Vector3 chestAxis = neck.position - up * (0.12f * ModelScale);
        float depth = SurfaceDistance(chestAxis, forward, avatarHeight * 0.03f, 0.096f * ModelScale);
        float push = Mathf.Max(0f, depth - 0.096f * ModelScale);
        PlaceModel("towel_gym", root, neck.position + forward * push, forward, up);
    }

    void BuildEarbuds()
    {
        var head = animator.GetBoneTransform(HumanBodyBones.Head);
        if (head == null) return;
        var root = NewRoot(head);
        Vector3 up = transform.up;
        Vector3 forward = TowardCamera(head);
        // 머리 뼈는 두개골 아랫부분(턱 높이)에 있어, 귀는 그보다 위에 있다.
        Vector3 axis = head.position + up * (avatarHeight * 0.06f) + forward * (avatarHeight * 0.03f);

        for (int side = -1; side <= 1; side += 2)
        {
            // 귀(헤어 옆면) 위치를 재서 이어폰 안쪽 팁을 붙인다.
            Vector3 outward = transform.right * side;
            float width = SurfaceDistance(axis, outward, avatarHeight * 0.03f, avatarHeight * 0.19f);
            PlaceModel("earbud", root, axis + outward * (width * 0.98f), forward, up, outward);
        }
    }

    /// <summary>
    /// Resources의 FBX를 인스턴스화한다. FBX 머티리얼의 기본 색만 가져와 공용 템플릿
    /// (Resources/Equipment/OunEquipmentLit: URP Lit + 약한 자체 발광)으로 바꾼다.
    /// 캐릭터는 조명 영향이 거의 없는 툰 셰이더라, 그냥 Lit이면 그늘진 면이 회색으로
    /// 가라앉아 흰 배번표·크림 단추가 칙칙해진다. 템플릿을 Resources에 두면 발광
    /// 변형(_EMISSION)도 빌드에 포함된다. 이름이 Hair_로 시작하는 머티리얼은 헤어 색으로 물들인다.
    /// 인스턴스 머티리얼은 GameObject와 함께 사라지지 않으므로 슬롯 해제 시 직접 지운다.
    /// </summary>
    GameObject InstantiateEquipmentModel(string resourcePath, Color? hairColor)
    {
        var prefab = Resources.Load<GameObject>(resourcePath);
        if (prefab == null)
            throw new System.InvalidOperationException("3D 아이템 FBX를 찾지 못했다: " + resourcePath);
        var template = Resources.Load<Material>("Equipment/OunEquipmentLit");
        var model = Instantiate(prefab);
        model.name = prefab.name;
        foreach (var child in model.GetComponentsInChildren<Transform>(true))
            child.gameObject.layer = gameObject.layer;
        if (!slotMaterials.TryGetValue(buildingSlot, out var list))
            slotMaterials[buildingSlot] = list = new List<Material>();
        foreach (var renderer in model.GetComponentsInChildren<Renderer>(true))
        {
            var source = renderer.sharedMaterials;
            var replaced = new Material[source.Length];
            for (int i = 0; i < source.Length; i++)
            {
                var original = source[i];
                Color color = original != null && original.HasProperty("_BaseColor")
                    ? original.GetColor("_BaseColor") : Color.white;
                string sourceName = original != null ? original.name : "";
                if (hairColor.HasValue && sourceName.StartsWith("Hair_"))
                {
                    // 결(Strand) 머티리얼은 살짝 밝게 해 땋은 마디가 구분되게 한다.
                    color = sourceName.StartsWith("Hair_Strand") ? hairColor.Value * 1.18f : hairColor.Value;
                }
                color.a = 1f;
                var material = template != null ? new Material(template) : new Material(original);
                material.name = sourceName;
                if (material.HasProperty("_BaseColor")) material.SetColor("_BaseColor", color);
                if (material.HasProperty("_EmissionColor")) material.SetColor("_EmissionColor", color * 0.4f);
                replaced[i] = material;
                list.Add(material);
            }
            renderer.sharedMaterials = replaced;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = false;
        }
        return model;
    }
}
