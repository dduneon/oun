using System.Collections;
using UnityEngine;

// Flutter <-> Unity 통신 브릿지.
// Flutter에서 sendToUnity("OunBridge", "React", message) 로 이 오브젝트의 React()가 호출된다.
// 반대로 SendToFlutter.Send()로 Flutter에 응답을 보낸다.
public class OunBridge : MonoBehaviour
{
    [Tooltip("반응시킬 캐릭터의 Transform. 비워두면 이 오브젝트 자신을 움직인다.")]
    public Transform character;

    [Tooltip("캐릭터 Animator. 비워두면 character 하위에서 자동으로 찾는다.")]
    public Animator animator;

    [Tooltip("손 흔들기 애니메이션을 재생하는 Trigger 파라미터 이름 (컨트롤러와 일치해야 함).")]
    public string waveTrigger = "Wave";

    [Tooltip("Animator가 없을 때 대체로 사용하는 점프 높이")]
    public float jumpHeight = 0.5f;

    [Tooltip("점프에 걸리는 시간(초)")]
    public float jumpDuration = 0.45f;

    [Header("씬 전환 (홈 ↔ 크루)")]
    [Tooltip("홈: 단일 캐릭터 그룹")]
    public GameObject homeRig;

    [Tooltip("크루: 여러 캐릭터가 모인 그룹")]
    public GameObject crewRig;

    [Tooltip("크루원 캐릭터를 인원수만큼 스폰하는 스포너(CrewRig에 부착)")]
    public CrewStage crewStage;

    [Tooltip("홈 캐릭터(사용자 본인 아바타)를 토큰으로 스폰하는 스포너(HomeRig에 부착). " +
             "크루와 같은 프리팹/규칙을 써 홈↔크루 캐릭터가 일치한다. z는 홈 카메라에 맞춰 원점 근처로.")]
    public CrewStage homeStage;

    [Tooltip("전환 시 위치·화각을 바꿀 카메라")]
    public Camera sceneCamera;

    [Header("홈 카메라")]
    public Vector3 homeCamPos = new Vector3(0f, 1.25f, -0.55f);
    public Vector3 homeCamEuler = new Vector3(20f, 180f, 0f);
    public float homeCamFov = 54f;

    [Header("크루 카메라 (여러 캐릭터가 보이도록 뒤로)")]
    public Vector3 crewCamPos = new Vector3(0f, 1.6f, -3.5f);
    public Vector3 crewCamEuler = new Vector3(12f, 180f, 0f);
    public float crewCamFov = 45f;

    bool isReacting;

    void Awake()
    {
        if (character == null) character = transform;
        if (animator == null) animator = character.GetComponentInChildren<Animator>();
    }

    void Start()
    {
        // Unity 엔진 준비 완료를 Flutter에 알린다. Flutter는 이 신호를 받고
        // 현재 씬(사용자 토큰 포함)을 최초로 보내온다("home:m" 등). 이렇게 해야
        // 엔진 로드 전에 보낸 메시지가 유실되는 문제 없이 첫 스폰이 이뤄진다.
        SendToFlutter.Send("unity_ready");
    }

    // Flutter가 씬 전환 시 호출: "home[:토큰]" 또는 "crew:토큰,토큰..." 형태.
    public void LoadScene(string arg)
    {
        bool crew = !string.IsNullOrEmpty(arg) && arg.StartsWith("crew");
        Debug.Log("LoadScene: " + arg);

        if (homeRig != null) homeRig.SetActive(!crew);
        if (crewRig != null) crewRig.SetActive(crew);

        if (crew)
        {
            // 크루 씬: "crew:토큰,토큰..."을 파싱해 인원수만큼 스폰.
            if (crewStage != null) crewStage.Spawn(ParseCrewMembers(arg));
        }
        else
        {
            if (crewStage != null) crewStage.Clear();
            // 홈 씬: 사용자 본인 아바타 1명을 토큰으로 스폰해 크루와 같은 캐릭터를 쓴다.
            // (고정 캐릭터를 없앤 대신 여기서 동적으로 세운다. 토큰 없으면 여성 폴백)
            if (homeStage != null)
            {
                homeStage.Spawn(new string[] { ParseHomeToken(arg) });
                // 스폰된 아바타를 React()/손흔들기 대상으로 다시 연결해야 홈 반응이 산다.
                var spawned = homeStage.FirstSpawned;
                if (spawned != null)
                {
                    character = spawned.transform;
                    animator = spawned.GetComponentInChildren<Animator>();
                }
            }
        }

        if (sceneCamera != null)
        {
            var t = sceneCamera.transform;
            if (crew)
            {
                // 인원수가 많을수록 카메라를 조금씩 뒤로 빼 다 담는다.
                var pos = crewCamPos;
                if (crewStage != null)
                {
                    int n = ParseCrewMembers(arg).Length;
                    pos.z = crewStage.RecommendedCamZ(n, crewCamPos.z);
                }
                t.localPosition = pos;
                t.localEulerAngles = crewCamEuler;
                sceneCamera.fieldOfView = crewCamFov;
            }
            else
            {
                t.localPosition = homeCamPos;
                t.localEulerAngles = homeCamEuler;
                sceneCamera.fieldOfView = homeCamFov;
            }
        }

        // Flutter에 준비 완료 알림(로딩 오버레이 제거용)
        SendToFlutter.Send(crew ? "crew_ready" : "home_ready");
    }

    // "crew:지민,현우,서연" → ["지민","현우","서연"]
    static string[] ParseCrewMembers(string arg)
    {
        int colon = arg.IndexOf(':');
        if (colon < 0 || colon + 1 >= arg.Length) return new string[0];
        return arg.Substring(colon + 1).Split(',');
    }

    // "home:m" → "m", "home" → "f"(폴백). 크루원 토큰과 같은 규칙('m'/'f').
    static string ParseHomeToken(string arg)
    {
        int colon = arg.IndexOf(':');
        if (colon < 0 || colon + 1 >= arg.Length) return "f";
        return arg.Substring(colon + 1).Trim();
    }

    // Flutter가 호출하는 메서드. public + string 파라미터 1개여야 UnitySendMessage로 호출된다.
    public void React(string message)
    {
        Debug.Log("Flutter -> Unity: " + message);

        // Animator + Wave 트리거가 있으면 손 흔들기 재생, 없으면 폴백으로 점프.
        if (animator != null && HasParameter(animator, waveTrigger))
        {
            animator.SetTrigger(waveTrigger);
        }
        else if (!isReacting)
        {
            StartCoroutine(Hop());
        }

        // 역방향 검증: Unity -> Flutter 응답
        SendToFlutter.Send("reacted:" + message);
    }

    static bool HasParameter(Animator anim, string paramName)
    {
        foreach (var p in anim.parameters)
        {
            if (p.name == paramName) return true;
        }
        return false;
    }

    IEnumerator Hop()
    {
        isReacting = true;
        Vector3 start = character.localPosition;
        float t = 0f;
        while (t < jumpDuration)
        {
            t += Time.deltaTime;
            float p = t / jumpDuration;
            // 0 -> 1 -> 0 포물선(사인)으로 폴짝
            float y = Mathf.Sin(p * Mathf.PI) * jumpHeight;
            character.localPosition = start + new Vector3(0f, y, 0f);
            yield return null;
        }
        character.localPosition = start;
        isReacting = false;
    }
}
