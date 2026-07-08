#!/usr/bin/env bash
#
# Build a Flutter web app for production and publish it outside the project.
#
#   Usage:  ./deploy-web.sh [admin|staff]     (defaults to admin)
#
# What it does:
#   1. flutter build web  with the production same-origin API base (/api/v1),
#      so the app calls the backend through nginx on its own origin (no CORS).
#   2. rsync the build OUT of the flutter project into /var/www/... (what nginx
#      serves), mirroring exactly (old files pruned).
#   3. pm2 restart the backend.
#
# Prerequisite: Flutter must be installed on the machine that runs this.
#
set -euo pipefail

TARGET="${1:-admin}"
API_BASE="/api/v1"          # same-origin; nginx proxies /api/ -> localhost:5100
PM2_APP="attendance-api-5100"

case "$TARGET" in
  admin) APP_DIR="admin_panel"; SERVE_DIR="/var/www/attendance-admin" ;;
  staff) APP_DIR="mobile_app";  SERVE_DIR="/var/www/attendance-staff" ;;
  *) echo "Usage: $0 [admin|staff]"; exit 1 ;;
esac

REPO="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO/$APP_DIR"

echo "==> [$TARGET] flutter build web  (API_BASE_URL=$API_BASE)"
flutter build web --release --dart-define=API_BASE_URL="$API_BASE"

echo "==> [$TARGET] publishing build/web -> $SERVE_DIR"
sudo mkdir -p "$SERVE_DIR"
sudo rsync -a --delete "build/web/" "$SERVE_DIR/"
sudo chown -R www-data:www-data "$SERVE_DIR"

echo "==> restarting backend ($PM2_APP)"
pm2 restart "$PM2_APP" --update-env || echo "   (pm2 app '$PM2_APP' not found — skipped)"

echo "==> [$TARGET] done  ->  $SERVE_DIR"
