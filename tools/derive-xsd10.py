#!/usr/bin/env python3
"""The official XSD needs XSD 1.1: it declares vc:minVersion="1.1", has 19 xs:assert
and an xs:all with repeating elements. libxml2 implements XSD 1.0 and won't compile it.
This makes a copy xmllint can load, removing the assertions and turning that xs:all
(GeneralLedgerEntries' Lines, which billing files don't have) into a repeating choice.
What it removes is checked by xmlschema against the untouched official file, in
tools/check-files.py. Usage: derive-xsd10.py official.xsd out.xsd"""
import re
import sys

source = open(sys.argv[1], "rb").read()
derived, asserts = re.subn(rb"[ \t]*<xs:assert\b[^>]*?/>\s*", b"", source, flags=re.S)
if asserts != 19:
    raise SystemExit(f"expected 19 assertions, found {asserts}: the schema changed, review this")
derived, alls = re.subn(rb"<xs:all>(.*?)</xs:all>", rb'<xs:choice maxOccurs="unbounded">\1</xs:choice>', derived, flags=re.S)
if alls != 1:
    raise SystemExit(f"expected one xs:all, found {alls}: the schema changed, review this")
derived = derived.replace(b' vc:minVersion="1.1"', b"")
open(sys.argv[2], "wb").write(derived)
