#!/usr/bin/env bash
# AT's demonstration file through the official XSD, this reader and writer. What comes
# back must hold the same Header, customers, suppliers, products, tax table and source
# documents, compared element by element by Python.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -I tools/derive-xsd10.py .sources/saftpt1.04_01.xsd build/saftpt-xsd10.xsd
build/at-demo .sources/saft_idemo599999999.xml build/at-demo-rewritten.xml
python3 tools/compare-at-demo.py .sources/saftpt1.04_01.xsd .sources/saft_idemo599999999.xml build/at-demo-rewritten.xml
