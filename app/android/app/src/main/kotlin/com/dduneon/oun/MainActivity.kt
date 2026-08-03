package com.dduneon.oun

import android.os.Build
import android.view.WindowInsets
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // UnityPlayer가 호스트 액티비티 창에 전체화면 플래그를 걸어 상태바를 먹는다
    // (Unity의 Fullscreen Mode 설정이 임베드된 우리 창에까지 적용된다).
    // 포커스를 받을 때마다 다시 걸기 때문에 Flutter의 SystemChrome 호출만으로는
    // 덮어써진다 — 액티비티에서 매번 되돌린다.
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) showSystemBars()
    }

    override fun onResume() {
        super.onResume()
        showSystemBars()
    }

    private fun showSystemBars() {
        window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.show(WindowInsets.Type.systemBars())
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = 0
        }
    }
}
