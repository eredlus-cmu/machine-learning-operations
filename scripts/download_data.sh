#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT="${REPO_ROOT}/data/input/credit_default.xls"
URL="https://archive.ics.uci.edu/ml/machine-learning-databases/00350/default%20of%20credit%20card%20clients.xls"
mkdir -p "$(dirname "${OUTPUT}")"
if [[ -f "${OUTPUT}" ]]; then echo "Dataset present: ${OUTPUT}"; exit 0; fi
echo "Downloading to ${OUTPUT}"
curl -fsSL "${URL}" -o "${OUTPUT}"
echo "Done."
