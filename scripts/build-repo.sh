#!/usr/bin/env bash
# build-repo.sh - Build Debian APT repository from .deb files in pool/
# Usage: ./scripts/build-repo.sh <repo-root>
#   repo-root: directory containing pool/ with .deb files

set -euo pipefail

REPO_ROOT="${1:-.}"
SUITE="stable"
COMPONENT="main"
ARCHS=("amd64" "arm64")
ORIGIN="${REPO_ORIGIN:-Deb Repo}"
LABEL="${REPO_LABEL:-Deb Repo}"

DISTS_DIR="${REPO_ROOT}/dists/${SUITE}"
POOL_DIR="${REPO_ROOT}/pool/${COMPONENT}"

# Ensure directories exist
mkdir -p "${POOL_DIR}"
for arch in "${ARCHS[@]}"; do
    mkdir -p "${DISTS_DIR}/${COMPONENT}/binary-${arch}"
done

# Detect architecture of a .deb file
detect_arch() {
    local deb_file="$1"
    local basename
    basename=$(basename "$deb_file")

    # Try filename first
    if [[ "$basename" =~ _(amd64|x86_64)\.deb$ ]]; then
        echo "amd64"
        return
    fi
    if [[ "$basename" =~ _(arm64|aarch64)\.deb$ ]]; then
        echo "arm64"
        return
    fi
    if [[ "$basename" =~ _all\.deb$ ]]; then
        echo "all"
        return
    fi

    # Fallback to dpkg-deb
    if command -v dpkg-deb &>/dev/null; then
        dpkg-deb --info "$deb_file" 2>/dev/null | grep '^ Architecture:' | awk '{print $2}'
        return
    fi

    echo "unknown"
}

# Generate Packages files for each architecture
echo "==> Scanning pool for .deb packages..."

for arch in "${ARCHS[@]}"; do
    PACKAGES_FILE="${DISTS_DIR}/${COMPONENT}/binary-${arch}/Packages"
    : > "${PACKAGES_FILE}"

    while IFS= read -r -d '' deb_file; do
        file_arch=$(detect_arch "$deb_file")

        # Include if arch matches, or if arch is "all"
        if [[ "$file_arch" == "$arch" || "$file_arch" == "all" ]]; then
            # Get package info via dpkg-deb
            dpkg-deb --info "$deb_file" 2>/dev/null | sed -n '/^ Package:/,/^$/p' | sed 's/^ //' > /dev/null 2>&1 || true

            # Use dpkg-scanpackages style output
            # Get control fields
            CONTROL=$(dpkg-deb --info "$deb_file" 2>/dev/null | sed '1,/^ /!d; 1d' || true)

            # Use dpkg-deb -I for clean control output
            dpkg-deb -I "$deb_file" control 2>/dev/null | while IFS= read -r line; do
                echo "$line"
            done >> "${PACKAGES_FILE}"

            # Compute file metadata
            REL_PATH=$(realpath --relative-to="$REPO_ROOT" "$deb_file")
            SIZE=$(stat -c%s "$deb_file")
            MD5=$(md5sum "$deb_file" | awk '{print $1}')
            SHA256=$(sha256sum "$deb_file" | awk '{print $1}')

            echo "Filename: ${REL_PATH}" >> "${PACKAGES_FILE}"
            echo "Size: ${SIZE}" >> "${PACKAGES_FILE}"
            echo "MD5sum: ${MD5}" >> "${PACKAGES_FILE}"
            echo "SHA256: ${SHA256}" >> "${PACKAGES_FILE}"
            echo "" >> "${PACKAGES_FILE}"
        fi
    done < <(find "${POOL_DIR}" -name '*.deb' -print0 2>/dev/null)

    # Generate compressed version
    gzip -9 -c "${PACKAGES_FILE}" > "${PACKAGES_FILE}.gz"

    PACKAGE_COUNT=$(grep -c '^Package:' "${PACKAGES_FILE}" 2>/dev/null || echo 0)
    echo "    ${arch}: ${PACKAGE_COUNT} package(s)"
done

# Generate Release file
echo "==> Generating Release file..."

RELEASE_FILE="${DISTS_DIR}/Release"

{
    echo "Origin: ${ORIGIN}"
    echo "Label: ${LABEL}"
    echo "Suite: ${SUITE}"
    echo "Codename: ${SUITE}"
    echo "Architectures: ${ARCHS[*]}"
    echo "Components: ${COMPONENT}"
    echo "Date: $(date -Ru)"
    echo "MD5Sum:"
} > "${RELEASE_FILE}"

# Add checksums for all index files
cd "${DISTS_DIR}"
for arch in "${ARCHS[@]}"; do
    for file in "${COMPONENT}/binary-${arch}/Packages" "${COMPONENT}/binary-${arch}/Packages.gz"; do
        if [[ -f "$file" ]]; then
            SIZE=$(stat -c%s "$file")
            MD5=$(md5sum "$file" | awk '{print $1}')
            printf ' %s %16d %s\n' "$MD5" "$SIZE" "$file" >> "Release"
        fi
    done
done

echo "SHA256:" >> "Release"
for arch in "${ARCHS[@]}"; do
    for file in "${COMPONENT}/binary-${arch}/Packages" "${COMPONENT}/binary-${arch}/Packages.gz"; do
        if [[ -f "$file" ]]; then
            SIZE=$(stat -c%s "$file")
            SHA256=$(sha256sum "$file" | awk '{print $1}')
            printf ' %s %16d %s\n' "$SHA256" "$SIZE" "$file" >> "Release"
        fi
    done
done
cd - > /dev/null

echo "    Release file generated at ${RELEASE_FILE}"

# GPG signing
if [[ -n "${GPG_KEY_ID:-}" ]] || gpg --list-secret-keys 2>/dev/null | grep -q 'sec'; then
    echo "==> Signing repository with GPG..."

    GPG_OPTS=()
    if [[ -n "${GPG_KEY_ID:-}" ]]; then
        GPG_OPTS+=(--default-key "${GPG_KEY_ID}")
    fi
    if [[ -n "${GPG_PASSPHRASE:-}" ]]; then
        GPG_OPTS+=(--batch --pinentry-mode loopback --passphrase "${GPG_PASSPHRASE}")
    fi

    # InRelease (clearsigned)
    gpg "${GPG_OPTS[@]}" --clearsign -o "${DISTS_DIR}/InRelease" "${RELEASE_FILE}"
    echo "    InRelease generated"

    # Release.gpg (detached signature)
    gpg "${GPG_OPTS[@]}" -abs -o "${DISTS_DIR}/Release.gpg" "${RELEASE_FILE}"
    echo "    Release.gpg generated"
else
    echo "==> WARNING: No GPG key found. Skipping repository signing."
    echo "    Users will need [trusted=yes] in their sources.list entry."
fi

echo "==> Repository build complete!"
