#!/usr/bin/env bash
set -euo pipefail

# Build the Co-op Synergies mod into a distributable .zip.
# The zip's internal layout is mods-unpacked/<id>/...  — exactly what Brotato's ModLoader
# expects (it mounts the zip at res://). .DS_Store is excluded.
#
# Usage:  ./build-zip.sh
# Output: dist/tato-Synergies.zip

MOD_ID="tato-Synergies"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/dist"
OUT="${OUT_DIR}/${MOD_ID}.zip"
CONFIG="${SCRIPT_DIR}/mods-unpacked/${MOD_ID}/config.gd"

if [ ! -d "${SCRIPT_DIR}/mods-unpacked/${MOD_ID}" ]; then
  echo "error: mod not found at ${SCRIPT_DIR}/mods-unpacked/${MOD_ID}" >&2
  exit 1
fi

# --- Toggle TEST_MODE + ENABLE_IN_SOLO on/off (cleanup trap restores originals) ---
CONFIG_BAK="${CONFIG}.bak"
cp "${CONFIG}" "${CONFIG_BAK}"
cleanup() { mv "${CONFIG_BAK}" "${CONFIG}"; }
trap cleanup EXIT

# Detect if this is a publish build (invoked from publish-steamcmd.sh) or a test build
if [ "${BUILD_RELEASE:-0}" = "1" ]; then
  sed -i '' 's/const TEST_MODE := true/const TEST_MODE := false/' "${CONFIG}"
  sed -i '' 's/const ENABLE_IN_SOLO := true/const ENABLE_IN_SOLO := false/' "${CONFIG}"
  echo "build-zip: RELEASE mode (TEST_MODE=false, ENABLE_IN_SOLO=false)"
else
  sed -i '' 's/const TEST_MODE := false/const TEST_MODE := true/' "${CONFIG}"
  sed -i '' 's/const ENABLE_IN_SOLO := false/const ENABLE_IN_SOLO := true/' "${CONFIG}"
  echo "build-zip: TEST mode (TEST_MODE=true, ENABLE_IN_SOLO=true)"
fi

mkdir -p "${OUT_DIR}"
rm -f "${OUT}"
# VFX assets: ship only the Vivid spritesheets the mod actually loads. Exclude the raw per-frame
# PNGs (*/Frames/*, we animate from the 4x4 sheets), the whole unused Stylized VFX pack, and any
# preview gifs/zips — keeps the published zip lean instead of carrying ~10MB of source art.
( cd "${SCRIPT_DIR}" && zip -r -q "${OUT}" "mods-unpacked/${MOD_ID}" \
    -x '*.DS_Store' -x '*.bak' \
    -x '*/Frames/*' \
    -x '*/Stylized VFX/*' \
    -x '*.gif' -x '*.zip' )

ICONS=$(unzip -l "${OUT}" | grep -c '\.png$' || true)
echo "Built: ${OUT}"
echo "  bundled skill icons: ${ICONS}"
echo "--- contents (must start with mods-unpacked/${MOD_ID}/) ---"
unzip -l "${OUT}" | sed -n '3,8p'
echo "Test locally: ./sync-to-mac.sh (after publishing + subscribing once)."
