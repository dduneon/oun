package com.dduneon.oun

import android.app.Activity
import android.os.Bundle
import android.widget.TextView
import android.widget.ScrollView

/** Health Connect's permissions rationale must work even with Flutter closed. */
class HealthPrivacyActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        title = "오운 건강 데이터 이용 안내"
        val text = TextView(this).apply {
            textSize = 17f
            setPadding(48, 48, 48, 48)
            text = "건강 데이터 이용 안내\n\n오운은 최근 30일의 운동 종류, 시작·종료 시각, 거리와 칼로리를 읽어 운동 기록 작성을 돕습니다.\n\n목록은 기기에서만 확인합니다. 사용자가 저장을 누른 운동의 정보와 원본 식별자만 오운 서버에 보관하며, 원본 건강 데이터는 변경하지 않습니다.\n\n선택하지 않은 운동은 서버로 전송하지 않습니다. 자동 또는 백그라운드 수집은 하지 않습니다.\n\nHealth Connect의 앱 권한에서 언제든 읽기 권한을 해제할 수 있습니다. 저장한 기록은 오운 기록 상세에서 삭제할 수 있습니다. 중복 보상 방지를 위한 원본 식별자는 회원 탈퇴까지 보관하며 삭제한 운동은 다시 가져올 수 없습니다. 회원 탈퇴 시 함께 삭제됩니다."
        }
        setContentView(ScrollView(this).apply { addView(text) })
    }
}
