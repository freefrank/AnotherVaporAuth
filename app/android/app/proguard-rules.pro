# mobile_scanner ships the bundled ML Kit barcode model. ML Kit wires itself
# up reflectively (MlKitComponentDiscoveryService manifest metadata -> the
# *Registrar classes), so R8 full mode strips those classes as "unused" and
# the scanner factory comes back null at runtime — release-only NPE in
# com.google.mlkit.vision.barcode.internal.zzg.a(BarcodeScannerOptions).
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.odml.** { *; }
-dontwarn com.google.mlkit.**
