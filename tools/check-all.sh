#!/usr/bin/env bash
# Every document type and the generated files through the official XSD 1.1, with abla-xml's
# validator (build/saft-xsd): the golden and valid files must pass, each invalid one must fail.
# Then control totals recomputed by build/check-files, and decimals by bc (tools/check-decimals.sh).
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
build/check-files "$out"/valid/*.xml
# The checker must fail on a file that is wrong in one place: each control total, a count and a
# document total is changed in the first file that has it, with nothing else touched.
mutants=$(mktemp -d)
trap 'rm -rf "$mutants"' EXIT
for tag in NumberOfEntries TotalDebit TotalCredit NumberOfMovementLines TotalQuantityIssued NetTotal TaxPayable GrossTotal CreditAmount DebitAmount; do
    files=$(grep -l "<$tag>" "$out"/valid/*.xml)
    file=${files%%$'\n'*}
    sed "0,/<$tag>/s//<$tag>1/" "$file" > "$mutants/$tag.xml"
    if build/check-files "$mutants/$tag.xml" > "$mutants/$tag.txt"; then
        echo "FAIL: check-files accepted $file with a changed $tag"
        exit 1
    fi
    echo "check-files refuses a changed $tag: $(grep -c '^FAIL' "$mutants/$tag.txt") differences"
    if [ "$tag" = TotalDebit ] || [ "$tag" = TotalQuantityIssued ]; then
        if build/check-big "$mutants/$tag.xml" > /dev/null; then
            echo "FAIL: check-big accepted $file with a changed $tag"
            exit 1
        fi
        echo "check-big refuses a changed $tag too"
    fi
done
# A line quantity of a stock movement, which TotalQuantityIssued adds up.
sed '0,/<Quantity>/s//<Quantity>1/' "$out/valid/movement-GT.xml" > "$mutants/Quantity.xml"
if build/check-files "$mutants/Quantity.xml" > /dev/null; then
    echo "FAIL: check-files accepted a changed movement Quantity"
    exit 1
fi
echo "check-files refuses a changed movement Quantity"
for file in "$out"/valid/*.xml; do build/check-big "$file" > /dev/null || { echo "FAIL: check-big on $file"; exit 1; }; done
echo "check-big agrees with check-files on every valid file"
tools/check-decimals.sh --self-test
build/decimal-vectors 20000 | tools/check-decimals.sh
