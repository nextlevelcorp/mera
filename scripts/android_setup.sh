#!/usr/bin/env bash
# Sets up a cloud session to export the "Android Debug" preset (roadmap R15):
# the Android command-line tools, platform 34, build-tools 34.0.0, the Godot
# Android export templates, a debug keystore and Godot's editor settings.
# Nothing here is a secret: the debug keystore uses Android's public debug
# password. Needs network access to dl.google.com, maven.google.com and
# github.com (and its release-assets host). Then:
#   mkdir -p build/android && godot --headless --path game --export-debug "Android Debug" ../build/android/mera-debug.apk
set -euo pipefail
SDK=/opt/android-sdk
KEYSTORE=/opt/android/debug.keystore
VERSION="${GODOT_VERSION:-$(tr -d '[:space:]' < "$(dirname "$0")/../.godot-version")}"
TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/${VERSION/-/.}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

if [ ! -d "$SDK/build-tools/34.0.0" ]; then
  mkdir -p "$SDK/cmdline-tools"
  curl -fsSL --retry 3 -o "$WORK/cmd.zip" https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
  unzip -q -o "$WORK/cmd.zip" -d "$SDK/cmdline-tools"
  rm -rf "$SDK/cmdline-tools/latest"; mv "$SDK/cmdline-tools/cmdline-tools" "$SDK/cmdline-tools/latest"
  yes | "$SDK/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK" "platform-tools" "build-tools;34.0.0" "platforms;android-34" >/dev/null
fi
if [ ! -f "$TEMPLATE_DIR/android_debug.apk" ]; then
  mkdir -p "$TEMPLATE_DIR"
  curl -fsSL --retry 3 -o "$WORK/tpl.tpz" "https://github.com/godotengine/godot-builds/releases/download/${VERSION}/Godot_v${VERSION}_export_templates.tpz"
  unzip -q -o -j "$WORK/tpl.tpz" 'templates/android_*' 'templates/version.txt' -d "$TEMPLATE_DIR"
fi
if [ ! -f "$KEYSTORE" ]; then
  mkdir -p "$(dirname "$KEYSTORE")"
  keytool -genkeypair -keystore "$KEYSTORE" -storepass android -alias androiddebugkey -keypass android \
    -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi
JAVA_HOME_DIR="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
mkdir -p "$HOME/.config/godot"
cat > "$HOME/.config/godot/editor_settings-4.4.tres" <<EOT
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$SDK"
export/android/java_sdk_path = "$JAVA_HOME_DIR"
export/android/debug_keystore = "$KEYSTORE"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
EOT
echo "Android export ready."
