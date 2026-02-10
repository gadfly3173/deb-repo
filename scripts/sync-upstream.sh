#!/usr/bin/env bash
# sync-upstream.sh - Download new .deb packages from upstream GitHub releases
# Usage: ./scripts/sync-upstream.sh <config-file> <pool-dir>
#
# Environment variables:
#   GH_TOKEN - GitHub token for API authentication (optional but recommended)
#
# Outputs (for CI):
#   Writes "new_packages=<count>" to $GITHUB_OUTPUT if available

set -euo pipefail

CONFIG="${1:?Usage: sync-upstream.sh <config-file> <pool-dir>}"
POOL_DIR="${2:?Usage: sync-upstream.sh <config-file> <pool-dir>}"

if [ ! -f "$CONFIG" ]; then
    echo "ERROR: Config file not found: ${CONFIG}"
    exit 1
fi

mkdir -p "${POOL_DIR}"

NEW_PACKAGES=0
REPO_COUNT=$(jq length "$CONFIG")
echo "==> Processing ${REPO_COUNT} upstream repository(ies)..."

AUTH_HEADER=()
if [ -n "${GH_TOKEN:-}" ]; then
    AUTH_HEADER=(-H "Authorization: Bearer ${GH_TOKEN}")
fi

for i in $(seq 0 $((REPO_COUNT - 1))); do
    OWNER=$(jq -r ".[$i].owner" "$CONFIG")
    REPO=$(jq -r ".[$i].repo" "$CONFIG")
    PATTERN=$(jq -r ".[$i].pattern // \"*.deb\"" "$CONFIG")

    echo ""
    echo "--- ${OWNER}/${REPO} (pattern: ${PATTERN}) ---"

    # Get latest release
    RELEASE_JSON=$(curl -sL \
        -H "Accept: application/vnd.github+json" \
        "${AUTH_HEADER[@]}" \
        "https://api.github.com/repos/${OWNER}/${REPO}/releases/latest" 2>/dev/null)

    TAG=$(echo "$RELEASE_JSON" | jq -r '.tag_name // empty')
    if [ -z "$TAG" ]; then
        echo "    No releases found, skipping"
        continue
    fi
    echo "    Latest release: ${TAG}"

    # Get .deb assets
    ASSETS=$(echo "$RELEASE_JSON" | jq -r \
        '[.assets[] | select(.name | test(".*\\.deb$")) | {name, url: .browser_download_url}]')

    ASSET_COUNT=$(echo "$ASSETS" | jq length)
    if [ "$ASSET_COUNT" -eq 0 ]; then
        echo "    No .deb assets found in release"
        continue
    fi
    echo "    Found ${ASSET_COUNT} .deb asset(s)"

    for j in $(seq 0 $((ASSET_COUNT - 1))); do
        ASSET_NAME=$(echo "$ASSETS" | jq -r ".[$j].name")
        ASSET_URL=$(echo "$ASSETS" | jq -r ".[$j].url")

        # Detect architecture from filename
        ARCH="unknown"
        if echo "$ASSET_NAME" | grep -qE '(amd64|x86_64)'; then
            ARCH="amd64"
        elif echo "$ASSET_NAME" | grep -qE '(arm64|aarch64)'; then
            ARCH="arm64"
        elif echo "$ASSET_NAME" | grep -qE '_all\.deb$'; then
            ARCH="all"
        fi

        # Skip if already exists in pool
        if [ -f "${POOL_DIR}/${ASSET_NAME}" ]; then
            echo "    [skip] ${ASSET_NAME} (already exists)"
            continue
        fi

        echo "    [download] ${ASSET_NAME} (${ARCH})"
        curl -sL -o "${POOL_DIR}/${ASSET_NAME}" "$ASSET_URL"

        if [ -f "${POOL_DIR}/${ASSET_NAME}" ]; then
            NEW_PACKAGES=$((NEW_PACKAGES + 1))
        else
            echo "    [error] Failed to download ${ASSET_NAME}"
        fi
    done
done

echo ""
echo "==> Downloaded ${NEW_PACKAGES} new package(s)"

# Write output for CI
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "new_packages=${NEW_PACKAGES}" >> "$GITHUB_OUTPUT"
fi
