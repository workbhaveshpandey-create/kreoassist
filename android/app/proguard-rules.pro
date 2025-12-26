# Flutter Llama Keep Rules
# Prevent R8 from stripping native callback classes
-keep class net.nativemind.flutter_llama.** { *; }
-keep class net.nativemind.flutter_llama.FlutterLlamaPlugin$* { *; }

# General Flutter Wrapper Keep (Safety)
-keep class io.flutter.plugins.** { *; }
