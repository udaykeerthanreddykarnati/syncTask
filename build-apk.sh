#!/bin/zsh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$DIR/android"
BUILD_DIR="$APP_DIR/build"
SDK_DIR="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
BUILD_TOOLS="$SDK_DIR/build-tools/34.0.0"
PLATFORM_JAR="$SDK_DIR/platforms/android-34/android.jar"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/gen" "$BUILD_DIR/obj" "$APP_DIR/assets"

# Extract embedded mobile HTML from SyncTask.swift into android/assets/index.html
awk '/static let embeddedMobileHTML = """/{flag=1; next} /^"""/{flag=0} flag' "$DIR/SyncTask.swift" > "$APP_DIR/assets/index.html"

"$BUILD_TOOLS/aapt2" compile --dir "$APP_DIR/res" -o "$BUILD_DIR/resources.zip"

"$BUILD_TOOLS/aapt2" link \
  -I "$PLATFORM_JAR" \
  --manifest "$APP_DIR/AndroidManifest.xml" \
  -A "$APP_DIR/assets" \
  -o "$BUILD_DIR/unaligned.apk" \
  --java "$BUILD_DIR/gen" \
  "$BUILD_DIR/resources.zip"

javac --release 8 \
  -cp "$PLATFORM_JAR" \
  -d "$BUILD_DIR/obj" \
  "$BUILD_DIR/gen/app/synctask/sync/R.java" \
  "$APP_DIR/src/app/synctask/sync/MainActivity.java" \
  "$APP_DIR/src/app/synctask/sync/SyncTaskWidgetProvider.java"

CLASS_FILES=($BUILD_DIR/obj/app/synctask/sync/*.class)
"$BUILD_TOOLS/d8" --lib "$PLATFORM_JAR" --output "$BUILD_DIR" "${CLASS_FILES[@]}"

(cd "$BUILD_DIR" && zip -q -u unaligned.apk classes.dex)

"$BUILD_TOOLS/zipalign" -f 4 "$BUILD_DIR/unaligned.apk" "$BUILD_DIR/aligned.apk"

KEYSTORE="$BUILD_DIR/release.keystore"
keytool -genkeypair -v \
  -keystore "$KEYSTORE" \
  -storepass android \
  -keypass android \
  -alias synctask \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "CN=synctask,O=synctask,C=US" >/dev/null 2>&1

"$BUILD_TOOLS/apksigner" sign \
  --ks "$KEYSTORE" \
  --ks-pass pass:android \
  --key-pass pass:android \
  --out "$DIR/synctask.apk" \
  "$BUILD_DIR/aligned.apk"

rm -rf "$BUILD_DIR" "$DIR/synctask.apk.idsig"
echo "Built $DIR/synctask.apk"
