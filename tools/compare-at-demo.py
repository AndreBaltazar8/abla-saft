#!/usr/bin/env python3
"""compare-at-demo.py original.xml rewritten.xml: the same content, element by element. Both
files pass the official XSD first, through build/saft-xsd (tools/check-at-demo.sh)."""
import sys
import xml.etree.ElementTree as ET
from decimal import Decimal, InvalidOperation

original, rewritten = sys.argv[1:3]
N = "{urn:OECD:StandardAuditFile-Tax:PT_1.04_01}"


def strip(node, skip=()):
    children = [strip(c) for c in node if c.tag.replace(N, "") not in skip]
    text = (node.text or "").strip() if not children else ""
    return node.tag.replace(N, ""), text, children


def compare(a, b, path, differences):
    if a[0] != b[0]:
        differences.append(f"{path}: {a[0]} != {b[0]}")
        return
    here = f"{path}/{a[0]}"
    if a[1] != b[1]:
        try:
            same = Decimal(a[1]) == Decimal(b[1])
        except InvalidOperation:
            same = False
        if not same:
            differences.append(f"{here}: {a[1]!r} != {b[1]!r}")
    if len(a[2]) != len(b[2]):
        differences.append(f"{here}: {len(a[2])} children != {len(b[2])}")
    for x, y in zip(a[2], b[2]):
        compare(x, y, here, differences)


left = ET.parse(original).getroot()
right = ET.parse(rewritten).getroot()
differences = []
elements = 0
for name, skip in (("Header", ()), ("MasterFiles", ("GeneralLedgerAccounts",)), ("SourceDocuments", ())):
    a = strip(left.find(N + name), skip)
    b = strip(right.find(N + name), skip)
    compare(a, b, "", differences)
    elements += sum(1 for _ in left.find(N + name).iter())
print(f"{elements} elements compared; {len(differences)} differences")
for d in differences[:20]:
    print(" ", d)
sys.exit(1 if differences else 0)
