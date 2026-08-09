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

# WorkManager keeps its queue in a Room database, and Room finds the generated
# implementation by name and calls its no-arg constructor. Nothing in the code
# calls that constructor, so R8 removes it, and because WorkManager starts from
# a ContentProvider the failure lands before the first frame: the app opens and
# closes again with no visible error. Keep the constructor on every generated
# Room database rather than naming this one, so a second database added later
# does not repeat it.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-dontwarn androidx.room.**
