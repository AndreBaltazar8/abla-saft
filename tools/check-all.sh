#!/usr/bin/env bash
# Every document type and the generated files through the official XSD 1.1, with abla-xml's
# validator (build/saft-xsd): the golden and valid files must pass, each invalid one must fail.
# Then control totals recomputed in Python, and decimals against Python's.
set -euo pipefail
cd "$(dirname "$0")/.."
out=build/files
rm -rf "$out"
mkdir -p "$out"
build/make-files "$out" "${1:-200}"
if ! SAFT_XSD_SHOWN=3 build/saft-xsd .sources/saftpt1.04_01.xsd tests/golden/*.xml "$out"/valid/*.xml > "$out/xsd.txt"; then
    grep -v ': errors 0$' "$out/xsd.txt"
    echo "FAIL: a golden or valid file doesn't pass the official XSD"
    exit 1
fi
echo "$(grep -c ': errors 0$' "$out/xsd.txt") golden and valid files pass the official XSD"
accepted=0
for file in "$out"/invalid/*.xml; do
    if SAFT_XSD_SHOWN=0 build/saft-xsd .sources/saftpt1.04_01.xsd "$file" > /dev/null; then
        echo "FAIL $file: the official XSD accepted a file meant to be invalid"
        accepted=$((accepted + 1))
    fi
done
echo "$(ls "$out"/invalid/*.xml | wc -l) invalid files refused by the official XSD, $accepted accepted"
[ "$accepted" -eq 0 ]
python3 tools/check-files.py "$out"
build/decimal-vectors 20000 | python3 tools/check-decimals.py
