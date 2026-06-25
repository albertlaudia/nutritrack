-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

-keep class com.baseflow.permissionhandler.** { *; }
-keep class io.flutter.plugins.camera.** { *; }

-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin
-keep class dev.steenbakker.mobile_scanner.** { *; }

# Supabase
-keep class io.supabase.** { *; }

# Isar (uses generated classes + reflection at runtime)
-keep class isar.** { *; }
-keep class **.isar.** { *; }
-keepclassmembers class * {
    @io.isar.annotation.Index *;
}

# Dio (annotation-driven interceptors)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn retrofit2.**
-keepattributes Signature, InnerClasses, EnclosingMethod
-keepattributes RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations

# Camera2 (used by mobile_scanner + camera plugin)
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# Google Fonts (downloads font files at runtime)
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Google Play Services (used by health plugin + mobile_scanner vision)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Image decoder (used by image package)
-keep class androidx.exifinterface.** { *; }

# General Flutter app hygiene — strip only what R8 can prove is unused
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile