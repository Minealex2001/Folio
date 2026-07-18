#!/usr/bin/env bash
set -euo pipefail

# Vercel no trae Flutter preinstalado: lo descargamos (fijado a la versión
# estable que usa el proyecto localmente) y compilamos la build web desde cero
# en cada deploy.
FLUTTER_VERSION="3.44.5"
FLUTTER_SDK_DIR="$HOME/flutter-sdk"

if [ ! -x "$FLUTTER_SDK_DIR/bin/flutter" ]; then
  echo "Descargando Flutter SDK $FLUTTER_VERSION..."
  rm -rf "$FLUTTER_SDK_DIR"
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$FLUTTER_SDK_DIR"
fi

export PATH="$FLUTTER_SDK_DIR/bin:$PATH"

flutter config --enable-web --no-analytics
flutter pub get
flutter build web --release --base-href /
