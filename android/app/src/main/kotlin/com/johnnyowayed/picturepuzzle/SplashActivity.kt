package com.johnnyowayed.picturepuzzle

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import androidx.core.view.WindowCompat

class SplashActivity : Activity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    WindowCompat.setDecorFitsSystemWindows(window, false)
    window.statusBarColor = Color.TRANSPARENT
    window.navigationBarColor = Color.TRANSPARENT
    setContentView(R.layout.activity_splash)

    window.decorView.post {
      startActivity(
        Intent(this, MainActivity::class.java).apply {
          addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION)
        },
      )
      finish()
      overridePendingTransition(0, 0)
    }
  }
}
