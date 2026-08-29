#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-$(git describe --tags --always --dirty)}"
# Sanitize version for RPM (no dashes allowed)
RPM_VERSION="${VERSION//-/_}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RPM_BUILD_DIR="${PROJECT_ROOT}/build/rpm"
SPEC_FILE="${PROJECT_ROOT}/packaging/linux/RPM/cashier-system.spec"

# Generate changelog date (RPM format: Day Mon DD YYYY)
CHANGELOG_DATE=$(date '+%a %b %d %Y')
BUILDER="Builder <builder@local>"

echo "Building RPM v${VERSION} (RPM version: ${RPM_VERSION})..."

# Set up rpmbuild directories FIRST
mkdir -p "${RPM_BUILD_DIR}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# Create source tarball (excluding build artifacts, .git, etc.)
cd "${PROJECT_ROOT}"
tar --exclude='.git' --exclude='build' --exclude='*.AppImage' --exclude='*.rpm' \
    -czf "${RPM_BUILD_DIR}/SOURCES/cashier-system-${RPM_VERSION}.tar.gz" .

# Generate spec with current date
sed "s/%%CHANGELOG_DATE%%/${CHANGELOG_DATE}/g; s/%%BUILDER%%/${BUILDER//\//\\/}/g" \
    "${SPEC_FILE}" > "${RPM_BUILD_DIR}/SPECS/cashier-system.spec"

# Build RPM
rpmbuild --define "_topdir ${RPM_BUILD_DIR}" \
         --define "version ${RPM_VERSION}" \
         ${ED25519_PUBKEY_HEX:+--define "ed25519_pubkey_hex ${ED25519_PUBKEY_HEX}"} \
         -ba "${RPM_BUILD_DIR}/SPECS/cashier-system.spec"

# Copy result
mkdir -p "${PROJECT_ROOT}/build/rpm/output"
cp "${RPM_BUILD_DIR}/RPMS/x86_64/cashier-system-${RPM_VERSION}-1.x86_64.rpm" \
   "${PROJECT_ROOT}/build/rpm/output/"

echo "RPM created: ${PROJECT_ROOT}/build/rpm/output/cashier-system-${RPM_VERSION}-1.x86_64.rpm"