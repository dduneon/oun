using System.Collections.Generic;
using UnityEngine;

// 크루 광장 캐릭터 스포너. 크루원 수만큼 캐릭터 프리팹을 런타임에 생성·배치한다.
// 정적 복사본 대신 이걸 쓰면 크루원이 늘고 줄 때 캐릭터도 따라간다.
public class CrewStage : MonoBehaviour
{
    [Tooltip("여성 캐릭터 프리팹")]
    public GameObject femalePrefab;

    [Tooltip("남성 캐릭터 프리팹")]
    public GameObject malePrefab;

    [Tooltip("캐릭터 사이 간격(가로)")]
    public float spacing = 0.7f;

    [Tooltip("캐릭터가 서는 깊이(z). 홈 캐릭터와 같은 값 권장")]
    public float z = -2.973f;

    [Tooltip("인원이 많아지면 간격을 자동으로 좁혀 담을 최대 폭")]
    public float maxWidth = 2.2f;

    readonly List<GameObject> _spawned = new List<GameObject>();

    // 스폰된 첫 캐릭터. 홈처럼 1명일 때 OunBridge가 React/손흔들기 대상으로 연결한다.
    public GameObject FirstSpawned => _spawned.Count > 0 ? _spawned[0] : null;

    // 각 크루원이 고른 캐릭터 종류('f'/'m')로 스폰. Flutter가 "crew:f,m,f..."로 보낸다.
    // (나중에는 종류뿐 아니라 아바타 config 전체를 받아 의상·헤어까지 개별 적용)
    public void Spawn(string[] tokens)
    {
        Clear();
        int n = tokens.Length;
        if (n == 0) return;

        // 인원이 많으면 간격을 좁혀 maxWidth 안에 담는다.
        float gap = spacing;
        if ((n - 1) * gap > maxWidth) gap = maxWidth / (n - 1);

        for (int i = 0; i < n; i++)
        {
            var prefab = PickPrefab(tokens[i]);
            if (prefab == null) continue;

            // 중앙 정렬: 좌우 대칭으로 벌린다.
            float x = (i - (n - 1) / 2f) * gap;
            var go = Instantiate(prefab, transform);
            go.transform.localPosition = new Vector3(x, 0f, z);
            go.name = "Member_" + i + "_" + tokens[i];
            go.SetActive(true);

            // TODO(B): 아바타 config로 의상·헤어 등 개별 적용
            _spawned.Add(go);
        }
    }

    // 'm'/'male'이면 남성, 그 외엔 여성. 해당 프리팹이 없으면 있는 쪽으로 대체.
    GameObject PickPrefab(string token)
    {
        token = (token ?? "").Trim().ToLower();
        bool male = token == "m" || token == "male";
        var chosen = male ? malePrefab : femalePrefab;
        return chosen != null ? chosen : (femalePrefab != null ? femalePrefab : malePrefab);
    }

    public void Clear()
    {
        foreach (var g in _spawned)
            if (g != null) Destroy(g);
        _spawned.Clear();
    }

    // 인원수에 맞춰 카메라를 얼마나 뒤로 빼면 좋은지(선택). OunBridge에서 활용 가능.
    public float RecommendedCamZ(int n, float baseZ)
    {
        float halfWidth = Mathf.Min((n - 1) * spacing, maxWidth) / 2f;
        return baseZ + halfWidth * 0.6f; // 넓을수록 조금 더 뒤로
    }
}
