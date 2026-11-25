#!/usr/bin/env bash
set -euo pipefail

# Explicit automated build mode avoids Flutter cloud-provider auto-detection.
export CI=true

# Use Flutter 3.38.10 / Dart 3.10.9. Production remains scripts/vercel-build.sh.
# No SUPABASE_* or other credentials are passed to this build.
base_href="${1:-/Portfolio/demos/vlinix/}"
flutter pub get
flutter test --dart-define=DEMO_MODE=true
flutter build web --release \
  --dart-define=DEMO_MODE=true \
  --base-href="$base_href" \
  --no-web-resources-cdn \
  --pwa-strategy=none
