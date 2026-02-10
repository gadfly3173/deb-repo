#!/usr/bin/env bash
# generate-pages.sh - Generate index.html and README.md for gh-pages from templates
# Usage: ./scripts/generate-pages.sh <output-dir> <repo-url> <templates-dir>

set -euo pipefail

OUTPUT_DIR="${1:-.}"
REPO_URL="${2:-https://example.github.io/deb-repo}"
TEMPLATES_DIR="${3:-templates}"

REPO_NAME=$(basename "$REPO_URL")
GITHUB_URL=$(echo "${REPO_URL}" | sed 's|https://\([^.]*\)\.github\.io/|https://github.com/\1/|')

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
