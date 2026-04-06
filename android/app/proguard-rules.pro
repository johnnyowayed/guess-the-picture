# Keep Flutter entry points and plugin registration.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep native method names that are looked up via JNI.
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep source file and line info for Crashlytics stack traces.
-keepattributes SourceFile,LineNumberTable

# Keep Google's Play services and Firebase classes that use reflection.
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.** { *; }

# Keep enum values used by reflection/serialization.
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Flutter may reference optional Play Core deferred-component classes.
# Suppress warnings/errors when deferred components are not used.
-dontwarn com.google.android.play.core.**
