# Release-build shrinking rules.

# flutter_local_notifications (study reminders): scheduled notifications are
# saved with Gson, which needs these classes and their generic types intact.
-keep class com.dexterous.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes Signature
-keepattributes *Annotation*

# Google Sign-In (google_sign_in v7 uses Android Credential Manager). Its
# Play Services provider is only found by reflection, so shrinking deletes
# it and the account sheet never appears in release builds.
-if class androidx.credentials.CredentialManager
-keep class androidx.credentials.playservices.** { *; }
