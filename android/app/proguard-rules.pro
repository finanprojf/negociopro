# Flutter — mantener clases de la app
-keep class com.finanprosolutions.negociopro.** { *; }

# Supabase / Ktor / OkHttp
-keep class io.github.jan.supabase.** { *; }
-keep class io.ktor.** { *; }
-dontwarn io.ktor.**
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-keep class okio.** { *; }
-dontwarn okio.**

# Kotlin serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keep,includedescriptorclasses class com.finanprosolutions.negociopro.**$$serializer { *; }
-keepclassmembers class com.finanprosolutions.negociopro.** {
    *** Companion;
}
-keepclasseswithmembers class com.finanprosolutions.negociopro.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# SQLite / sqflite
-keep class org.sqlite.** { *; }
-keep class org.sqlite.database.** { *; }

# Google Fonts / Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Mantener nombres de clases para reflexión de Dart/JNI
-keepattributes Signature
-keepattributes Exceptions
-keepattributes SourceFile,LineNumberTable

# Evitar warnings de librerías que no usamos directamente
-dontwarn com.google.android.play.**
-dontwarn javax.annotation.**
