#!/usr/bin/env bash
# Configura el proyecto iOS que genera `flutter create` (no se versiona, igual que
# la capa Gradle de Android). Corre en macOS (CI o un Mac local):
#
#   flutter create . --project-name finaid --org co --platforms ios
#   bash tool/ios/configure.sh
#
# - Esquema de URL `finaid://` (captura desde Atajos).
# - Texto de permiso de Face ID (bloqueo de la app).
# - Nombre visible "Finaid".
# - Ícono de la app a partir de docs/brand/finaid-icon-ios.svg (si macOS puede
#   renderizarlo; si no, queda el ícono por defecto y el build sigue).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PLIST="$ROOT/ios/Runner/Info.plist"
PB=/usr/libexec/PlistBuddy

[ -f "$PLIST" ] || { echo "No existe $PLIST: corre flutter create primero" >&2; exit 1; }

pb_set() { # clave tipo valor
  $PB -c "Set :$1 $3" "$PLIST" 2>/dev/null || $PB -c "Add :$1 $2 $3" "$PLIST"
}

pb_set CFBundleDisplayName string "Finaid"
pb_set NSFaceIDUsageDescription string "Finaid usa Face ID para proteger tus movimientos."

$PB -c "Delete :CFBundleURLTypes" "$PLIST" 2>/dev/null || true
$PB -c "Add :CFBundleURLTypes array" "$PLIST"
$PB -c "Add :CFBundleURLTypes:0 dict" "$PLIST"
$PB -c "Add :CFBundleURLTypes:0:CFBundleURLName string co.finaid.ingest" "$PLIST"
$PB -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$PLIST"
$PB -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string finaid" "$PLIST"

$PB -c "Delete :LSApplicationQueriesSchemes" "$PLIST" 2>/dev/null || true
$PB -c "Add :LSApplicationQueriesSchemes array" "$PLIST"
$PB -c "Add :LSApplicationQueriesSchemes:0 string shortcuts" "$PLIST"

echo "Info.plist configurado:"
$PB -c "Print :CFBundleURLTypes" "$PLIST"

# --- Ícono (mejor esfuerzo) ---------------------------------------------------
ICONSET="$ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset"
SVG="$ROOT/docs/brand/finaid-icon-ios.svg"
if [ -d "$ICONSET" ] && [ -f "$SVG" ] && command -v qlmanage >/dev/null && command -v sips >/dev/null; then
  TMP="$(mktemp -d)"
  if qlmanage -t -s 1024 -o "$TMP" "$SVG" >/dev/null 2>&1 && [ -f "$TMP/$(basename "$SVG").png" ]; then
    SRC="$TMP/$(basename "$SVG").png"
    # Sin canal alfa (App Store / iOS lo exigen): pasar por JPEG y volver a PNG.
    sips -s format jpeg "$SRC" --out "$TMP/icon.jpg" >/dev/null
    sips -s format png "$TMP/icon.jpg" --out "$TMP/icon.png" >/dev/null
    for f in "$ICONSET"/*.png; do
      w=$(sips -g pixelWidth "$f" | awk '/pixelWidth/ {print $2}')
      sips -z "$w" "$w" "$TMP/icon.png" --out "$f" >/dev/null
    done
    echo "Ícono de Finaid aplicado ($(ls "$ICONSET"/*.png | wc -l | tr -d ' ') tamaños)."
  else
    echo "No se pudo renderizar el SVG del ícono; se mantiene el ícono por defecto."
  fi
  rm -rf "$TMP"
fi
