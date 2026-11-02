#!/usr/bin/env bash
# AT's demonstration file through the official XSD, this reader and writer. What comes
# back must pass the XSD too, and hold the same Header, customers, suppliers, products, tax
# table and source documents, compared element by element by Python.
set -euo pipefail
cd "$(dirname "$0")/.."
build/at-demo .sources/saft_idemo599999999.xml build/at-demo-rewritten.xml
build/saft-xsd .sources/saftpt1.04_01.xsd .sources/saft_idemo599999999.xml build/at-demo-rewritten.xml
python3 tools/compare-at-demo.py .sources/saft_idemo599999999.xml build/at-demo-rewritten.xml
