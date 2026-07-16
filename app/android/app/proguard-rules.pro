# mobile_scanner ships the bundled ML Kit barcode model. ML Kit wires itself
# up reflectively (MlKitComponentDiscoveryService manifest metadata -> the
# *Registrar classes), so R8 full mode strips those classes as "unused" and
# the scanner factory comes back null at runtime — release-only NPE in
# com.google.mlkit.vision.barcode.internal.zzg.a(BarcodeScannerOptions).
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.odml.** { *; }
-dontwarn com.google.mlkit.**

# WorkManager (pulled in transitively by play-services-ads): Room creates the
# generated database via reflection (Class.forName("...WorkDatabase_Impl")),
# so R8 full mode strips it and the app crashes at process start in the
# androidx.startup InitializationProvider — release-only, play flavor only.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-dontwarn androidx.work.**

# The play channel is reached ONLY via reflection from MainActivity
# (Class.forName keeps the cn flavor free of any static reference), which
# also means R8 sees no reference and strips it — play features silently
# die in release builds without this.
-keep class pro.dotslash.ava.play.PlayChannel {
    public static void register(...);
}
