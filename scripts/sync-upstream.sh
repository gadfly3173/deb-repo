#!/usr/bin/env bash
# sync-upstream.sh - Download new .deb packages from upstream GitHub/GitLab releases
# Usage: ./scripts/sync-upstream.sh <config-file> <pool-dir>
#
# Environment variables:
#   GH_TOKEN - GitHub token for API authentication (optional but recommended)
#   GL_TOKEN - GitLab token for API authentication (optional)
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

glob_to_regex() {
    local glob="$1"
    local regex

    # Escape regex meta characters first
    regex=$(printf '%s' "$glob" | sed -e 's/[][(){}.+^$|\\]/\\&/g')
    # Convert shell globs to regex
    regex=$(printf '%s' "$regex" | sed -e 's/\*/.*/g' -e 's/\?/./g')

    printf '^%s$' "$regex"
}

NEW_PACKAGES=0
REPO_COUNT=$(jq length "$CONFIG")
echo "==> Processing ${REPO_COUNT} upstream repository(ies)..."

GH_AUTH_HEADER=()
if [ -n "${GH_TOKEN:-}" ]; then
    GH_AUTH_HEADER=(-H "Authorization: Bearer ${GH_TOKEN}")
fi

GL_AUTH_HEADER=()
if [ -n "${GL_TOKEN:-}" ]; then
    GL_AUTH_HEADER=(-H "PRIVATE-TOKEN: ${GL_TOKEN}")
fi

for i in $(seq 0 $((REPO_COUNT - 1))); do
    PROVIDER=$(jq -r ".[$i].provider // \"github\"" "$CONFIG")
    OWNER=$(jq -r ".[$i].owner // empty" "$CONFIG")
    REPO=$(jq -r ".[$i].repo // empty" "$CONFIG")
    PROJECT=$(jq -r ".[$i].project // empty" "$CONFIG")
    PATTERN=$(jq -r ".[$i].pattern // \"*.deb\"" "$CONFIG")
    PATTERN_REGEX=$(glob_to_regex "$PATTERN")

    RELEASE_JSON=""
    TAG=""
    ASSETS="[]"
    TARGET_DESC=""
    DOWNLOAD_AUTH_HEADER=()

    case "$PROVIDER" in
        github)
            if [ -z "$OWNER" ] || [ -z "$REPO" ]; then
                echo ""
                echo "--- [skip] Invalid GitHub config at index ${i}: owner/repo is required ---"
                continue
            fi

            TARGET_DESC="${OWNER}/${REPO}"
            DOWNLOAD_AUTH_HEADER=("${GH_AUTH_HEADER[@]}")

            echo ""
            echo "--- github: ${TARGET_DESC} (pattern: ${PATTERN}) ---"

            RELEASE_JSON=$(curl -fsSL \
                -H "Accept: application/vnd.github+json" \
                "${GH_AUTH_HEADER[@]}" \
                "https://api.github.com/repos/${OWNER}/${REPO}/releases/latest" 2>/dev/null || true)

            TAG=$(echo "$RELEASE_JSON" | jq -r '.tag_name // empty')

            ASSETS=$(echo "$RELEASE_JSON" | jq -r \
                --arg pattern_regex "$PATTERN_REGEX" \
                '[.assets[]?
                  | select(.name | test(".*\\.deb$"))
                  | select(.name | test($pattern_regex))
                  | {name, url: .browser_download_url}]')
            ;;
        gitlab)
            if [ -z "$PROJECT" ]; then
                if [ -n "$OWNER" ] && [ -n "$REPO" ]; then
                    PROJECT="${OWNER}/${REPO}"
                fi
            fi

            if [ -z "$PROJECT" ]; then
                echo ""
                echo "--- [skip] Invalid GitLab config at index ${i}: project or owner/repo is required ---"
                continue
            fi

            TARGET_DESC="$PROJECT"
            DOWNLOAD_AUTH_HEADER=("${GL_AUTH_HEADER[@]}")

            echo ""
            echo "--- gitlab: ${TARGET_DESC} (pattern: ${PATTERN}) ---"

            PROJECT_ENCODED=$(jq -nr --arg v "$PROJECT" '$v|@uri')
            RELEASE_JSON=$(curl -fsSL \
                -H "Accept: application/json" \
                "${GL_AUTH_HEADER[@]}" \
                "https://gitlab.com/api/v4/projects/${PROJECT_ENCODED}/releases/permalink/latest" 2>/dev/null || true)

            TAG=$(echo "$RELEASE_JSON" | jq -r '.tag_name // empty')

            ASSETS=$(echo "$RELEASE_JSON" | jq -r \
                --arg pattern_regex "$PATTERN_REGEX" \
                '[.assets.links[]?
                  | .download_url = (.direct_asset_url // .url // "")
                  | select(.download_url != "")
                  | .asset_name = (if (.name // "" | test(".*\\.deb$"))
                                   then .name
                                   else (.download_url | split("?")[0] | split("/") | last)
                                   end)
                  | select(.asset_name | test(".*\\.deb$"))
                  | select(.asset_name | test($pattern_regex))
                  | {name: .asset_name, url: .download_url}]')
            ;;
        *)
            echo ""
            echo "--- [skip] Unsupported provider '${PROVIDER}' at index ${i} ---"
            continue
            ;;
    esac

    # Validate release
    if [ -z "$TAG" ]; then
        echo "    No releases found, skipping"
        continue
    fi
    echo "    Latest release: ${TAG}"

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
        if ! curl -fsSL "${DOWNLOAD_AUTH_HEADER[@]}" -o "${POOL_DIR}/${ASSET_NAME}" "$ASSET_URL"; then
            echo "    [error] Failed to download ${ASSET_NAME}"
            rm -f "${POOL_DIR}/${ASSET_NAME}"
            continue
        fi

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
