# Flutter's engine is reached through JNI, so R8 cannot see the references and
# strips them without these.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# flutter_local_notifications keeps its scheduled notifications as serialised
# gson, so the classes it reflects over have to survive.
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# Play Core is referenced by the engine's deferred components support, which
# this app does not use. Without this R8 fails on the missing classes.
-dontwarn com.google.android.play.core.**
