#!/usr/bin/env python3
"""Records what xmlschema, an independent XSD 1.1 validator, says of each file of
tests/xsd/mutations.txt, for tests/xsd_test.ab to compare with: valid or invalid, and where
its first error is (the element's path without positions, and its line). Run from the
repository with `make xsd-expected`; needs xmlschema and lxml. Usage: xsd-expected.py official.xsd"""
import sys

import xmlschema
from lxml import etree

schema = xmlschema.XMLSchema11(sys.argv[1])
parser = etree.XMLParser(resolve_entities=False, no_network=True, huge_tree=True)


def unescape(text):
    return text.replace("\\n", "\n").encode("utf-8")


print(f"# xmlschema {xmlschema.__version__} on {sys.argv[1]}: name, verdict, path, line, reason")
for row in open("tests/xsd/mutations.txt", encoding="utf-8"):
    row = row.rstrip("\n")
    if not row or row.startswith("#"):
        continue
    name, path, nth, find, replace = row.split("\t")
    data = open(path, "rb").read()
    find, replace = unescape(find), unescape(replace)
    at = -1
    for _ in range(int(nth)):
        at = data.find(find, at + 1)
        if at < 0:
            raise SystemExit(f"{name}: occurrence {nth} of the text isn't in {path}")
    data = data[:at] + replace + data[at + len(find):]
    try:
        document = etree.fromstring(data, parser).getroottree()
    except etree.XMLSyntaxError as e:
        print(f"{name}\tinvalid\t-\t{e.lineno}\tnot well-formed")
        continue
    errors = list(schema.iter_errors(document))
    if not errors:
        print(f"{name}\tvalid\t-\t-\t-")
        continue
    e = errors[0]
    where = "/" + "/".join(step.split(":")[-1].split("}")[-1].split("[")[0] for step in (e.path or "").strip("/").split("/") if step)
    reason = (e.reason or "").replace("\n", " ").replace("\t", " ")[:160]
    print(f"{name}\tinvalid\t{where}\t{e.sourceline}\t{reason}")
