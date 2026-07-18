using System.Collections;
using UnityEngine;

// Flutter <-> Unity 통신 브릿지.
// Flutter에서 sendToUnity("OunBridge", "React", message) 로 이 오브젝트의 React()가 호출된다.
// 반대로 SendToFlutter.Send()로 Flutter에 응답을 보낸다.
public class OunBridge : MonoBehaviour
{
    [Tooltip("반응시킬 캐릭터의 Transform. 비워두면 이 오브젝트 자신을 움직인다.")]
    public Transform character;

    [Tooltip("점프 높이")]
    public float jumpHeight = 0.5f;

    [Tooltip("점프에 걸리는 시간(초)")]
    public float jumpDuration = 0.45f;

    bool isReacting;

    void Awake()
    {
        if (character == null) character = transform;
    }

    // Flutter가 호출하는 메서드. public + string 파라미터 1개여야 UnitySendMessage로 호출된다.
    public void React(string message)
    {
        Debug.Log("Flutter -> Unity: " + message);
        if (!isReacting) StartCoroutine(Hop());
        // 역방향 검증: Unity -> Flutter 응답
        SendToFlutter.Send("reacted:" + message);
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
