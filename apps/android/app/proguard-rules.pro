# Add project specific ProGuard rules here.

# Kotlin
-keepattributes *Annotation*
-keepclassmembers class **$WhenMappings {
    <fields>;
}

# Moshi
-keepclasseswithmembers class * {
    @com.squareup.moshi.* <methods>;
}
-keep @com.squareup.moshi.JsonQualifier interface *
-keepclassmembers @com.squareup.moshi.JsonClass class * extends java.lang.Enum {
    <fields>;
    **[] values();
}

# Retrofit
-keepattributes Signature, InnerClasses, EnclosingMethod
-keepattributes RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations
-keepclassmembers,allowshrinking,allowobfuscation interface * {
    @retrofit2.http.* <methods>;
}

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**

# Hilt
-keepnames @dagger.hilt.android.lifecycle.HiltViewModel class * extends androidx.lifecycle.ViewModel

# ── Moshi codegen adapters + @JsonClass models (R8 release safety) ──
# Moshi codegen 으로 생성된 *_JsonAdapter 와 @JsonClass(generateAdapter=true)
# 모델을 R8 이 strip/obfuscate 하면 런타임 JSON 파싱이 깨진다(릴리스 한정).
# 생성 어댑터와 모델 클래스명·필드를 보존한다.
-keep,allowobfuscation,allowshrinking @com.squareup.moshi.JsonClass class *
-keep class **JsonAdapter {
    <init>(...);
    <fields>;
}
-keepnames @com.squareup.moshi.JsonClass class *
# DTO 모델 패키지의 필드명 보존 (@Json(name=...) 미사용 필드는 코틀린 프로퍼티명으로 매핑됨)
-keepclassmembers @com.squareup.moshi.JsonClass class * {
    <fields>;
}
# Moshi 내부
-keep class com.squareup.moshi.** { *; }
-keep interface com.squareup.moshi.** { *; }
-keepclassmembers class * {
    @com.squareup.moshi.FromJson <methods>;
    @com.squareup.moshi.ToJson <methods>;
}

# ── Retrofit/Kotlin 메타데이터 (suspend 함수 + 제네릭 응답 타입 보존) ──
-keep,allowobfuscation,allowshrinking class kotlin.coroutines.Continuation
-keep,allowobfuscation,allowshrinking interface retrofit2.Call
-keep,allowobfuscation,allowshrinking class retrofit2.Response
