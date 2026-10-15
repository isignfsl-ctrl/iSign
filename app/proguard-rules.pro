# iSigns ProGuard Rules
# Add project specific ProGuard rules here.

# Keep all model classes for Firebase serialization
-keep class com.example.isigns.model.** { *; }

# Keep UserProgressRepository for SharedPreferences
-keep class com.example.isigns.data.UserProgressRepository { *; }
-keep class com.example.isigns.data.FirestoreSignRepository { *; }
-keep class com.example.isigns.data.CombinedSignRepository { *; }
-keep class com.example.isigns.data.SignRepository { *; }

# Keep Compose UI components
-keep class com.example.isigns.ui.** { *; }

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep Media3/ExoPlayer
-keep class androidx.media3.** { *; }
-keep class com.google.android.exoplayer2.** { *; }

# Keep Firebase Firestore
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.firebase.auth.** { *; }

# Keep Kotlinx Coroutines
-keep class kotlinx.coroutines.** { *; }

# Keep Room (if used)
-keep class androidx.room.** { *; }

# Keep Datastore
-keep class androidx.datastore.** { *; }

# Keep Protobuf
-keep class com.google.protobuf.** { *; }

# Keep Material3
-keep class androidx.compose.material3.** { *; }

# Keep Compose runtime
-keep class androidx.compose.runtime.** { *; }
-keep class androidx.compose.ui.** { *; }

# Keep lifecycle
-keep class androidx.lifecycle.** { *; }

# Keep Activity Compose
-keep class androidx.activity.compose.** { *; }

# Keep Compose UI Test
-keep class androidx.compose.ui.test.** { *; }

# Keep Firebase Storage
-keep class com.google.firebase.storage.** { *; }

# Keep shared preferences
-keep class android.content.SharedPreferences { *; }

# Preserve line numbers for debugging
-keepattributes SourceFile,LineNumberTable

# Keep annotations
-keepattributes *Annotation*

# Keep Enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable
-keep class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Keep Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep Kotlin metadata
-keep class kotlin.Metadata { *; }

# Keep Compose internal
-keep class androidx.compose.runtime.internal.** { *; }

# Keep Firebase auto-value
-keep class com.google.auto.value.** { *; }

# Keep protobuf generated
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }