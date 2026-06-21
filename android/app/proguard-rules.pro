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