#!/usr/bin/env bash
set -euo pipefail

# Publish the Co-op Synergies mod to the Steam Workshop via SteamCMD — WITHOUT
# GodotWorkshopUtility, so the Workshop title from workshop_item.vdf sticks
# (GodotWorkshopUtility has no title field and force-sets the title to the mod id).
#
# FIRST RUN (new item): workshop_item.vdf has  "publishedfileid" "0"  -> steamcmd CREATES
# a new Workshop item and prints its id (PublishedFileID). Paste that id back into
# workshop_item.vdf's "publishedfileid" so every later run UPDATES that same item.
#
# Prereqs:
#   - steamcmd installed:        brew install --cask steamcmd
#   - the Steam account you log in with OWNS Brotato (and, after creation, owns this item)
#   - a preview image at thumbnail.png  (you provide this)
#
# Usage:
#   ./publish-steamcmd.sh <steam_account>
#   (the first login prompts for your Steam Guard code, interactively)

MOD_ID="tato-Synergies"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="${SCRIPT_DIR}/dist"
CONTENT="${DIST}/content"                       # the folder Steam uploads: must hold ONLY the zip
TEMPLATE="${SCRIPT_DIR}/workshop_item.vdf"
GENERATED="${DIST}/workshop_item.generated.vdf" # template with absolute paths filled in
PREVIEW="${SCRIPT_DIR}/thumbnail.jpeg"

STEAM_ACCOUNT="${1:-}"
if [ -z "${STEAM_ACCOUNT}" ]; then
  echo "usage: $0 <steam_account>" >&2
  exit 1
fi

if ! command -v steamcmd >/dev/null 2>&1; then
  echo "error: steamcmd not found. Install it: brew install --cask steamcmd" >&2
  exit 1
fi
[ -f "${TEMPLATE}" ] || { echo "error: missing ${TEMPLATE}" >&2; exit 1; }
[ -f "${PREVIEW}" ]  || { echo "error: missing preview image ${PREVIEW} (add your thumbnail.png)" >&2; exit 1; }

# 1) Build the mod zip (release mode: TEST_MODE=false).
BUILD_RELEASE=1 "${SCRIPT_DIR}/build-zip.sh" >/dev/null
[ -f "${DIST}/${MOD_ID}.zip" ] || { echo "error: build did not produce ${DIST}/${MOD_ID}.zip" >&2; exit 1; }

# 2) Stage a clean content folder containing ONLY the zip (ModLoader loads the zip at the
#    item root). steamcmd replaces the item's content with everything in contentfolder.
rm -rf "${CONTENT}"
mkdir -p "${CONTENT}"
cp "${DIST}/${MOD_ID}.zip" "${CONTENT}/"

# 3) Render the .vdf with ABSOLUTE paths (steamcmd resolves contentfolder/previewfile from
#    its own cwd, so relative paths are unreliable). '|' avoids clashing with '/' in paths.
sed -e "s|__CONTENTFOLDER__|${CONTENT}|g" \
    -e "s|__PREVIEWFILE__|${PREVIEW}|g" \
    "${TEMPLATE}" > "${GENERATED}"

echo "--- ${GENERATED} ---"
cat "${GENERATED}"
echo "------------------------------------------------------------"

if grep -q '"publishedfileid"[[:space:]]*"0"' "${GENERATED}"; then
  echo "NOTE: publishedfileid is 0 -> this CREATES a new Workshop item."
  echo "      After it succeeds, copy the printed PublishedFileID into ${TEMPLATE}."
fi

# 4) Upload. First login is interactive (Steam Guard). On success steamcmd prints the id.
echo "Uploading as Steam account '${STEAM_ACCOUNT}'…"
steamcmd +login "${STEAM_ACCOUNT}" +workshop_build_item "${GENERATED}" +quit

echo "Done. If this was the first upload, paste the PublishedFileID into ${TEMPLATE}."
