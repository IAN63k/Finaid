#!/usr/bin/env sh
# Usage: tool/bump_version.sh MAJOR.MINOR.PATCH [path/to/pubspec.yaml]
# Sets `version:` in pubspec.yaml to the given semver and increments the build number (+N).
set -eu

NEW="${1:-}"
PUBSPEC="${2:-$(dirname "$0")/../pubspec.yaml}"

if ! printf '%s' "$NEW" | grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'; then
  echo "error: version must be MAJOR.MINOR.PATCH (got '${NEW}')" >&2
  exit 1
fi
[ -f "$PUBSPEC" ] || { echo "error: pubspec not found: $PUBSPEC" >&2; exit 1; }

OLD_LINE="$(grep -E '^version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+(\+[0-9]+)?[[:space:]]*$' "$PUBSPEC" | head -n 1 || true)"
[ -n "$OLD_LINE" ] || { echo "error: no 'version: X.Y.Z[+N]' line found in $PUBSPEC" >&2; exit 1; }

OLD="$(printf '%s' "$OLD_LINE" | tr -d '\r' | sed -E 's/^version:[[:space:]]*//; s/[[:space:]]*$//')"
BUILD="$(printf '%s' "$OLD" | sed -nE 's/^[^+]*\+([0-9]+)$/\1/p')"
if [ -n "$BUILD" ]; then NEW_BUILD=$((BUILD + 1)); else NEW_BUILD=1; fi
NEW_FULL="${NEW}+${NEW_BUILD}"

TMP="${PUBSPEC}.tmp"
# Rewrite only the first matching version line; strip CR so the file stays LF.
awk -v nv="version: ${NEW_FULL}" '
  !done && /^version:[ \t]*[0-9]+\.[0-9]+\.[0-9]+(\+[0-9]+)?[ \t]*\r?$/ { print nv; done=1; next }
  { sub(/\r$/, ""); print }
' "$PUBSPEC" > "$TMP" && mv "$TMP" "$PUBSPEC"

echo "pubspec.yaml: ${OLD} -> ${NEW_FULL}"

# Versión visible dentro de la app (lib/core/app_info.dart), si existe.
APP_INFO="$(dirname "$PUBSPEC")/lib/core/app_info.dart"
if [ -f "$APP_INFO" ]; then
  sed -i.bak -E "s/'Finaid [0-9]+\.[0-9]+\.[0-9]+'/'Finaid ${NEW}'/" "$APP_INFO" && rm -f "${APP_INFO}.bak"
  echo "lib/core/app_info.dart: Finaid ${NEW}"
fi

echo
echo "Next steps:"
echo "  git add pubspec.yaml lib/core/app_info.dart CHANGELOG.md"
echo "  git commit -m \"chore(release): v${NEW}\""
echo "  git tag -a v${NEW} -m \"Finaid v${NEW}\""
echo "  git push --follow-tags"
