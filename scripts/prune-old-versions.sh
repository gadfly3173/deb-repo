#!/usr/bin/env bash
# prune-old-versions.sh - Keep only latest .deb per package and architecture
# Usage: ./scripts/prune-old-versions.sh <pool-dir>
#
# Outputs (for CI):
#   Writes "pruned_packages=<count>" to $GITHUB_OUTPUT if available

set -euo pipefail

POOL_DIR="${1:?Usage: ./scripts/prune-old-versions.sh <pool-dir>}"

if ! command -v dpkg-deb >/dev/null 2>&1; then
    echo "ERROR: dpkg-deb is required but not found"
    exit 1
fi

if ! command -v dpkg >/dev/null 2>&1; then
    echo "ERROR: dpkg is required but not found"
    exit 1
fi

mkdir -p "${POOL_DIR}"

declare -a DEB_FILES=()
while IFS= read -r -d '' deb_file; do
    DEB_FILES+=("${deb_file}")
done < <(find "${POOL_DIR}" -maxdepth 1 -type f -name '*.deb' -print0 2>/dev/null | sort -z)

if [ "${#DEB_FILES[@]}" -eq 0 ]; then
    echo "==> No .deb packages found in ${POOL_DIR}"
    if [ -n "${GITHUB_OUTPUT:-}" ]; then
        echo "pruned_packages=0" >> "${GITHUB_OUTPUT}"
    fi
    exit 0
fi

declare -A BEST_VERSION_BY_KEY
declare -A BEST_FILE_BY_KEY
declare -A FILE_KEY
declare -A FILE_VERSION

for deb_file in "${DEB_FILES[@]}"; do
    pkg_name=$(dpkg-deb -f "${deb_file}" Package 2>/dev/null || true)
    pkg_version=$(dpkg-deb -f "${deb_file}" Version 2>/dev/null || true)
    pkg_arch=$(dpkg-deb -f "${deb_file}" Architecture 2>/dev/null || true)

    if [ -z "${pkg_name}" ] || [ -z "${pkg_version}" ] || [ -z "${pkg_arch}" ]; then
        echo "    [warn] Skip invalid deb metadata: $(basename "${deb_file}")"
        continue
    fi

    key="${pkg_name}:${pkg_arch}"
    FILE_KEY["${deb_file}"]="${key}"
    FILE_VERSION["${deb_file}"]="${pkg_version}"

    if [ -z "${BEST_VERSION_BY_KEY[${key}]:-}" ]; then
        BEST_VERSION_BY_KEY["${key}"]="${pkg_version}"
        BEST_FILE_BY_KEY["${key}"]="${deb_file}"
        continue
    fi

    current_best_version="${BEST_VERSION_BY_KEY[${key}]}"
    current_best_file="${BEST_FILE_BY_KEY[${key}]}"

    if dpkg --compare-versions "${pkg_version}" gt "${current_best_version}"; then
        BEST_VERSION_BY_KEY["${key}"]="${pkg_version}"
        BEST_FILE_BY_KEY["${key}"]="${deb_file}"
    elif dpkg --compare-versions "${pkg_version}" eq "${current_best_version}"; then
        # Deterministic tie-breaker: keep lexicographically larger filename.
        if [[ "$(basename "${deb_file}")" > "$(basename "${current_best_file}")" ]]; then
            BEST_FILE_BY_KEY["${key}"]="${deb_file}"
        fi
    fi
done

PRUNED_COUNT=0
for deb_file in "${DEB_FILES[@]}"; do
    key="${FILE_KEY[${deb_file}]:-}"
    if [ -z "${key}" ]; then
        continue
    fi

    latest_file="${BEST_FILE_BY_KEY[${key}]}"
    if [ "${deb_file}" != "${latest_file}" ]; then
        latest_version="${BEST_VERSION_BY_KEY[${key}]}"
        current_version="${FILE_VERSION[${deb_file}]}"
        echo "    [prune] $(basename "${deb_file}") (${current_version}) -> keep $(basename "${latest_file}") (${latest_version})"
        rm -f "${deb_file}"
        PRUNED_COUNT=$((PRUNED_COUNT + 1))
    fi
done

REMAINING_COUNT=$(find "${POOL_DIR}" -maxdepth 1 -type f -name '*.deb' | wc -l | awk '{print $1}')
echo "==> Pruned ${PRUNED_COUNT} old package(s), remaining ${REMAINING_COUNT} latest package(s)"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "pruned_packages=${PRUNED_COUNT}" >> "${GITHUB_OUTPUT}"
fi
