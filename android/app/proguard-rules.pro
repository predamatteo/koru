# Tink (androidx.security:security-crypto → tink-android) referenzia
# annotation di compile-time non incluse nell'APK. Senza i -dontwarn R8
# fallisce con "Missing class com.google.errorprone.annotations.*" /
# "Missing class javax.annotation.*". Le annotation sono SOURCE/CLASS
# retention only, non servono a runtime.
# Generate da R8: build/app/outputs/mapping/release/missing_rules.txt.
-dontwarn com.google.errorprone.annotations.CanIgnoreReturnValue
-dontwarn com.google.errorprone.annotations.CheckReturnValue
-dontwarn com.google.errorprone.annotations.Immutable
-dontwarn com.google.errorprone.annotations.RestrictedApi
-dontwarn javax.annotation.Nullable
-dontwarn javax.annotation.concurrent.GuardedBy
