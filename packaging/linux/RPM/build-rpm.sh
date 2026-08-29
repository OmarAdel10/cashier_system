#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-$(git describe --tags --always --dirty)}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RPM_BUILD_DIR="${PROJECT_ROOT}/build/rpm"
SPEC_FILE="${PROJECT_ROOT}/packaging/linux/RPM/cashier-system.spec"

echo "Building RPM v${VERSION}..."

# Set up rpmbuild directories FIRST
mkdir -p "${RPM_BUILD_DIR}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# Create source tarball (excluding build artifacts, .git, etc.)
cd "${PROJECT_ROOT}"
tar --exclude='.git' --exclude='build' --exclude='*.AppImage' --exclude='*.rpm' \
    -czf "${RPM_BUILD_DIR}/SOURCES/cashier-system-${VERSION}.tar.gz" .

# Copy spec
cp "${SPEC_FILE}" "${RPM_BUILD_DIR}/SPECS/"

# Build RPM
rpmbuild --define "_topdir ${RPM_BUILD_DIR}" \
         --define "version ${VERSION}" \
         ${ED25519_PUBKEY_HEX:+--define "ed25519_pubkey_hex ${ED25519_PUBKEY_HEX}"} \
         -ba "${RPM_BUILD_DIR}/SPECS/cashier-system.spec"

# Copy result
mkdir -p "${PROJECT_ROOT}/build/rpm/output"
cp "${RPM_BUILD_DIR}/RPMS/x86_64/cashier-system-${VERSION}-1.x86_64.rpm" \
   "${PROJECT_ROOT}/build/rpm/output/"

echo "RPM created: ${PROJECT_ROOT}/build/rpm/output/cashier-system-${VERSION}-1.x86_64.rpm"