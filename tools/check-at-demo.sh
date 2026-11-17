#!/usr/bin/env bash
# AT's demonstration file through the official XSD, this reader and writer. What comes
# back must pass the XSD too, and hold the same Header, customers, suppliers, products, tax
# table and source documents, compared element by element by build/compare-at-demo.
set -euo pipefail
cd "$(dirname "$0")/.."
build/at-demo .sources/saft_idemo599999999.xml build/at-demo-rewritten.xml
build/saft-xsd .sources/saftpt1.04_01.xsd .sources/saft_idemo599999999.xml build/at-demo-rewritten.xml
build/compare-at-demo .sources/saft_idemo599999999.xml build/at-demo-rewritten.xml
# The comparison must fail on a rewrite that is wrong in one place, and pass on one that differs
# only in how a decimal is written.
mutant=$(mktemp)
trap 'rm -f "$mutant"' EXIT
sed '0,/<TaxPayable>/s//<TaxPayable>1/' build/at-demo-rewritten.xml > "$mutant"
if build/compare-at-demo .sources/saft_idemo599999999.xml "$mutant" > /dev/null; then
    echo "FAIL: a changed TaxPayable was not found"
    exit 1
fi
sed '0,/<CompanyName>/s//<CompanyName>X/' build/at-demo-rewritten.xml > "$mutant"
if build/compare-at-demo .sources/saft_idemo599999999.xml "$mutant" > /dev/null; then
    echo "FAIL: a changed CompanyName was not found"
    exit 1
fi
awk '/<Description>/ && !done { done = 1; next } { print }' build/at-demo-rewritten.xml > "$mutant"
if build/compare-at-demo .sources/saft_idemo599999999.xml "$mutant" > /dev/null; then
    echo "FAIL: a missing element was not found"
    exit 1
fi
echo "the comparison refuses a changed total, a changed name and a missing element"
awk '/<TaxPercentage>/ && !done { sub(/<\/TaxPercentage>/, "00&"); done = 1 } { print }' build/at-demo-rewritten.xml > "$mutant"
cmp -s "$mutant" build/at-demo-rewritten.xml && { echo "FAIL: the trailing zeros were not written"; exit 1; }
build/compare-at-demo .sources/saft_idemo599999999.xml "$mutant" > /dev/null
echo "and accepts a decimal written with more zeros"
