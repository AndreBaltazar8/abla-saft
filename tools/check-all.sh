#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
out=build/files
rm -rf "$out"
mkdir -p "$out"
build/make-files "$out" "${1:-200}"
python3 -I tools/derive-xsd10.py .sources/saftpt1.04_01.xsd build/saftpt-xsd10.xsd
python3 tools/check-files.py .sources/saftpt1.04_01.xsd build/saftpt-xsd10.xsd "$out"
build/decimal-vectors 20000 | python3 tools/check-decimals.py
