package com.johnnyowayed.picturepuzzle

import android.content.pm.ApplicationInfo
import android.os.Build
import android.os.Bundle
import android.os.Debug
import java.io.File
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    if (isReleaseBuild() && isPotentiallyCompromised()) {
      finishAffinity()
      return
    }

    super.onCreate(savedInstanceState)
  }

  private fun isPotentiallyCompromised(): Boolean {
    return isDebuggerAttached() || isAppDebuggable() || isRootLikely()
  }

  private fun isReleaseBuild(): Boolean {
    return (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) == 0
  }

  private fun isDebuggerAttached(): Boolean {
    return Debug.isDebuggerConnected() || Debug.waitingForDebugger()
  }

  private fun isAppDebuggable(): Boolean {
    return (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
  }

  private fun isRootLikely(): Boolean {
    if (Build.TAGS?.contains("test-keys") == true) return true

    val knownRootPaths =
      listOf(
        "/system/app/Superuser.apk",
        "/sbin/su",
        "/system/bin/su",
        "/system/xbin/su",
        "/data/local/xbin/su",
        "/data/local/bin/su",
        "/system/sd/xbin/su",
        "/system/bin/failsafe/su",
        "/data/local/su",
        "/su/bin/su",
        "/system/xbin/daemonsu",
      )

    return knownRootPaths.any { File(it).exists() }
  }
}
