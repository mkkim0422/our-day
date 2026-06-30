# 그날 우리 — R8/ProGuard 규칙
# 릴리스 빌드에서 코드 축소·난독화 시 깨지면 안 되는 클래스 보존.
# Flutter Gradle 플러그인이 Flutter 엔진/플러그인 기본 규칙은 자동 포함하지만,
# 본 앱이 쓰는 네이티브 연동 플러그인은 명시적으로 한 번 더 지켜준다.

# --- Flutter 엔진 ---
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# --- flutter_local_notifications (예약/부팅 리시버 리플렉션) ---
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# --- Google Sign-In / Drive(클라우드 백업) ---
-keep class com.google.android.gms.** { *; }
-keep class com.google.api.** { *; }
-dontwarn com.google.**

# --- 코어 라이브러리 디슈가링 ---
-dontwarn java.lang.invoke.**

# --- 일반: 네이티브 메서드·열거형·시리얼라이즈 보존 ---
-keepclasseswithmembernames class * {
    native <methods>;
}
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
-keepattributes Signature, *Annotation*, EnclosingMethod, InnerClasses
