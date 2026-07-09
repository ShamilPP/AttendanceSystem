#!/usr/bin/env bash
#
# Build the Flutter web app(s) into  <repo>/build/{admin,staff}.
#
#   Usage:  ./deploy-web.sh [admin|staff|both]     (default: both)
#
# Notes:
#   - Builds with the production same-origin API base (/api/v1); nginx proxies
#     /api/ -> the backend, so each app calls the API on its own origin (no CORS).
#   - Output goes to a top-level build/ folder (outside each flutter project):
#       build/admin  <- admin panel
#       build/staff  <- employee app
#   - Does NOT touch pm2 (restart the backend yourself if you need to).
#
set -euo pipefail

API_BASE="/api/v1"
REPO="$(cd "$(dirname "$0")" && pwd)"

build_one() {
  local target="$1" app_dir out_dir
  case "$target" in
    admin) app_dir="admin_panel"; out_dir="$REPO/build/admin" ;;
    staff) app_dir="mobile_app";  out_dir="$REPO/build/staff" ;;
    *) echo "unknown target: $target"; return 1 ;;
  esac
  echo "==> [$target] flutter build web  (API_BASE_URL=$API_BASE)"
  ( cd "$REPO/$app_dir" && flutter build web --release --dart-define=API_BASE_URL="$API_BASE" )
  echo "==> [$target] publish -> $out_dir"
  rm -rf "$out_dir"; mkdir -p "$out_dir"
  cp -R "$REPO/$app_dir/build/web/." "$out_dir/"
  echo "==> [$target] done -> $out_dir"
}

case "${1:-both}" in
  admin) build_one admin ;;
  staff) build_one staff ;;
  both)  build_one admin; build_one staff ;;
  *) echo "Usage: $0 [admin|staff|both]"; exit 1 ;;
esac

echo "All builds done."
