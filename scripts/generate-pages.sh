#!/usr/bin/env bash
# generate-pages.sh - Generate index.html and README.md for gh-pages from templates
# Usage: ./scripts/generate-pages.sh <output-dir> <repo-url> <templates-dir> [github-url]

set -euo pipefail

OUTPUT_DIR="${1:-.}"
REPO_URL="${2:-https://example.github.io/deb-repo}"
TEMPLATES_DIR="${3:-templates}"
GITHUB_URL="${4:-}"

REPO_URL="${REPO_URL%/}"

if [ -z "${GITHUB_URL}" ]; then
    if [ -n "${GITHUB_REPOSITORY:-}" ]; then
        GITHUB_URL="https://github.com/${GITHUB_REPOSITORY}"
    else
        GITHUB_URL=$(echo "${REPO_URL}" | sed 's|https://\([^.]*\)\.github\.io/|https://github.com/\1/|')
    fi
fi

# Prefer repository slug for naming (keyring filename, source file name, page title)
REPO_NAME=""

if [ -n "${GITHUB_REPOSITORY:-}" ]; then
    REPO_NAME="$(basename "${GITHUB_REPOSITORY}")"
elif [ -n "${GITHUB_URL}" ]; then
    GITHUB_URL_CLEAN="${GITHUB_URL%/}"
    REPO_NAME="$(basename "${GITHUB_URL_CLEAN}")"
fi

if [ -z "${REPO_NAME}" ]; then
    # Fallback: use URL path segment if exists (e.g. /deb-repo)
    URL_PATH=$(printf '%s' "${REPO_URL}" | sed -E 's|^[a-zA-Z]+://[^/]+/?||')
    if [ -n "${URL_PATH}" ] && [ "${URL_PATH}" != "${REPO_URL}" ]; then
        REPO_NAME="$(basename "${URL_PATH}")"
    fi
fi

if [ -z "${REPO_NAME}" ]; then
    REPO_NAME="deb-repo"
fi

if [ ! -f "${TEMPLATES_DIR}/gh-pages-index.html" ]; then
    echo "ERROR: Template ${TEMPLATES_DIR}/gh-pages-index.html not found"
    exit 1
fi

# Replace placeholders in templates and write output
for pair in "gh-pages-index.html:index.html" "gh-pages-README.md:README.md"; do
    TEMPLATE="${pair%%:*}"
    OUTPUT="${pair##*:}"

    sed \
        -e "s|{{REPO_URL}}|${REPO_URL}|g" \
        -e "s|{{REPO_NAME}}|${REPO_NAME}|g" \
        -e "s|{{GITHUB_URL}}|${GITHUB_URL}|g" \
        "${TEMPLATES_DIR}/${TEMPLATE}" > "${OUTPUT_DIR}/${OUTPUT}"

    echo "Generated ${OUTPUT}"
done
