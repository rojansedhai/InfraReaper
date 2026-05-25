#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.13.4}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
WORK_DIR="${DIST_DIR}/terraform-layer"

mkdir -p "${WORK_DIR}/bin" "${DIST_DIR}"
curl -fsSL "https://releases.hashicorp.com/terraform/${VERSION}/terraform_${VERSION}_linux_amd64.zip" -o "${DIST_DIR}/terraform.zip"
unzip -o "${DIST_DIR}/terraform.zip" -d "${WORK_DIR}/bin"
chmod +x "${WORK_DIR}/bin/terraform"

(cd "${WORK_DIR}" && zip -qr "${DIST_DIR}/terraform-layer.zip" bin)
echo "Created ${DIST_DIR}/terraform-layer.zip"

