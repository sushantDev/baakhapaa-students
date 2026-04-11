# Add these rules for Media3
-keepclassmembers class * implements androidx.media3.common.util.UnstableApi {
    *;
}
-keep class androidx.media3.** { *; }
-keep interface androidx.media3.** { *; }
-dontwarn androidx.media3.**

# SLF4J missing classes
-dontwarn org.slf4j.**
-dontwarn org.slf4j.impl.**
-keep class org.slf4j.** { *; }
-keep class org.slf4j.impl.** { *; }

# General rules for libraries that might use reflection
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Keep Khalti classes
-keep class com.khalti.** { *; }
-dontwarn com.khalti.**

# Keep YouTube player classes
-keep class com.pierfrancescosoffritti.** { *; }
-dontwarn com.pierfrancescosoffritti.**

# For Pusher Channels
-keep class com.pusher.** { *; }
-dontwarn com.pusher.**

# Media Kit related
-keep class com.alexmiller.** { *; }
-keep class media.kit.** { *; }
-dontwarn media.kit.**

# For YouTube Explode
-keep class com.github.kotvertolet.** { *; }

# Home Widget
-keep class com.baakhapaa.com.ReadingStreakWidget { *; }
-keep class es.antonborri.home_widget.** { *; }

# Stripe push provisioning (not used, suppress R8 warnings)
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider