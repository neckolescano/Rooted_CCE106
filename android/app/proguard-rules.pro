# Release-build shrinking rules.

# flutter_local_notifications (study reminders): scheduled notifications are
# saved with Gson, which needs these classes and their generic types intact.
-keep class com.dexterous.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes Signature
-keepattributes *Annotation*
