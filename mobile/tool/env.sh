# Ambiente da toolchain Flutter instalada em espaço de utilizador.
# Uso:  source mobile/tool/env.sh
export TOOLS="$HOME/.flutter-toolchain"
export JAVA_HOME="$TOOLS/jdk17"
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="$TOOLS/flutter/bin:$JAVA_HOME/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"
