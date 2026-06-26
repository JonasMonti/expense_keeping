# Google ML Kit — reconhecimento de texto (ler faturas).
# Usamos apenas o script latino; o plugin referencia os reconhecedores
# opcionais (chinês, japonês, coreano, devanagari) que não estão incluídos.
# Sem estas regras, o R8 falha no release com "Missing class …".
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.common.** { *; }
