# ─────────── Flutter / plugin registry ───────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# ─────────── flutter_local_notifications ──────────────────────────
# The plugin uses reflection to instantiate scheduled-notification
# receivers and to deserialise notification payload classes after a
# device reboot. Without these keeps it silently loses scheduled work.
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }

# Gson (used by flutter_local_notifications for payload de/ser).
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# ─────────── audioplayers ─────────────────────────────────────────
-keep class xyz.luan.audioplayers.** { *; }

# ─────────── drift / sqlite3 native loader ────────────────────────
-keep class org.sqlite.** { *; }
-keep class com.tekartik.** { *; }

# ─────────── googleapis / Drive client ────────────────────────────
# The googleapis Drive client deserialises JSON responses via
# reflection. Keep model classes; warnings about optional deps OK.
-keep class com.google.api.** { *; }
-keep class com.google.auth.** { *; }
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**

# ─────────── google_sign_in_all_platforms ─────────────────────────
# Native Google Sign-In on Android uses Credential Manager which
# requires its model classes intact.
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.libraries.identity.googleid.** { *; }
-dontwarn com.google.android.gms.**

# ─────────── App ──────────────────────────────────────────────────
-keep class com.mirit.reminders.mirit_reminders.MainActivity { *; }

# desugar_jdk_libs noise
-dontwarn java.lang.invoke.StringConcatFactory

# Play Core Split-Install — Flutter references it for deferred components,
# we don't use them so the classes are absent. Suppress R8 warnings.
-dontwarn com.google.android.play.core.**
