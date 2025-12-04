# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase rules
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Keep PDF and Excel libraries (optimize)
-keep class com.** { *; }
-dontwarn com.**

# Keep data models
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
}

# Additional optimizations to reduce size
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}

# Remove logging in release builds
-assumenosideeffects class kotlin.io.ConsoleKt {
    public static void println(...);
}

# Optimize: Remove unused classes
-dontwarn javax.annotation.**
-dontwarn kotlin.**
-dontwarn kotlinx.**

