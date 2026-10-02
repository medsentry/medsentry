#!/bin/bash
set -e

echo "=== Installing Flutter SDK on Vercel ==="
if [ ! -d "_flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable _flutter
fi

export PATH="$PATH:$(pwd)/_flutter/bin"

echo "=== Flutter Version ==="
flutter --version

echo "=== Getting Dependencies ==="
flutter config --no-analytics
flutter pub get

echo "=== Building Flutter Web (Release) ==="
flutter build web --release --base-href /

echo "=== Build Complete! ==="
