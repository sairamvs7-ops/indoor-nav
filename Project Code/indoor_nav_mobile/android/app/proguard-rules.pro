# ML Kit text recognition: only the Latin model is bundled (it works offline).
# The plugin also refers to the Chinese, Devanagari, Japanese and Korean
# models, which are left out on purpose, so R8 must not fail on them.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-keep class com.google.mlkit.vision.text.** { *; }
