#!/usr/bin/env python3
"""A file too big to load, read once with iterparse, keeping nothing: recomputes every
control total independently of the library, and writes a sample with the header, master
files and every Nth document of each section, which is small enough for the official XSD.
Control totals in the sample aren't right, which the XSD can't see.
Usage: check-big.py file sample every"""
import sys
import xml.etree.ElementTree as ET
from decimal import Decimal

path, sample, every = sys.argv[1], sys.argv[2], int(sys.argv[3])
NS = "urn:OECD:StandardAuditFile-Tax:PT_1.04_01"
N = "{" + NS + "}"
ET.register_namespace("", NS)
SECTIONS = {
    "SalesInvoices": ("Invoice", "InvoiceStatus", ("A", "F")),
    "WorkingDocuments": ("WorkDocument", "WorkStatus", ("A",)),
    "Payments": ("Payment", "PaymentStatus", ("A",)),
    "MovementOfGoods": ("StockMovement", "MovementStatus", ("A",)),
}
failures = 0
documents = 0


def fail(message):
    global failures
    failures += 1
    print("FAIL", message)


out = open(sample, "wb")
out.write(b'<?xml version="1.0" encoding="UTF-8"?>\n<AuditFile xmlns="' + NS.encode() + b'">')
section = None
state = {}
stack = []
parents = []
for event, el in ET.iterparse(path, events=("start", "end")):
    name = el.tag.replace(N, "")
    if event == "start":
        stack.append(name)
        parents.append(el)
        if len(stack) == 2 and name == "SourceDocuments":
            out.write(b"<SourceDocuments>")
        if len(stack) == 3 and name in SECTIONS:
            section = name
            state = dict(count=0, debit=Decimal(0), credit=Decimal(0), lines=0, quantity=Decimal(0), kept=0, opened=False)
            out.write(f"<{name}>".encode())
        continue
    depth = len(stack)
    stack.pop()
    parents.pop()
    if depth == 2 and name in ("Header", "MasterFiles"):
        out.write(ET.tostring(el, encoding="utf-8", xml_declaration=False).replace(b' xmlns="' + NS.encode() + b'"', b""))
        el.clear()
    elif depth == 4 and section and name == SECTIONS[section][0]:
        documents += 1
        state["count"] += 1
        status = el.find(f"{N}DocumentStatus/{N}{SECTIONS[section][1]}").text
        for line in el.findall(N + "Line"):
            state["lines"] += 1
            if status not in SECTIONS[section][2]:
                a = line.find(N + "DebitAmount")
                b = line.find(N + "CreditAmount")
                if a is not None:
                    state["debit"] += Decimal(a.text)
                if b is not None:
                    state["credit"] += Decimal(b.text)
                q = line.find(N + "Quantity")
                if q is not None:
                    state["quantity"] += Decimal(q.text)
        if state["count"] % every == 1 or every == 1:
            out.write(ET.tostring(el, encoding="utf-8", xml_declaration=False).replace(b' xmlns="' + NS.encode() + b'"', b""))
        parents[-1].remove(el)
    elif depth == 4 and section:
        state[name] = el.text
        out.write(f"<{name}>{el.text}</{name}>".encode())
        el.clear()
    elif depth == 3 and name in SECTIONS:
        if name == "MovementOfGoods":
            if int(state["NumberOfMovementLines"]) != state["lines"]:
                fail(f"{name} lines {state['NumberOfMovementLines']} != {state['lines']}")
            if Decimal(state["TotalQuantityIssued"]) != state["quantity"]:
                fail(f"{name} quantity {state['TotalQuantityIssued']} != {state['quantity']}")
        else:
            if int(state["NumberOfEntries"]) != state["count"]:
                fail(f"{name} entries {state['NumberOfEntries']} != {state['count']}")
            if Decimal(state["TotalDebit"]) != state["debit"]:
                fail(f"{name} debit {state['TotalDebit']} != {state['debit']}")
            if Decimal(state["TotalCredit"]) != state["credit"]:
                fail(f"{name} credit {state['TotalCredit']} != {state['credit']}")
        print(f"{name}: {state['count']} documents, {state['lines']} lines, totals recomputed")
        out.write(f"</{name}>".encode())
        section = None
        el.clear()
    elif depth == 2 and name == "SourceDocuments":
        out.write(b"</SourceDocuments>")
        el.clear()
out.write(b"</AuditFile>\n")
out.close()
print(f"{documents} documents, {failures} failures")
sys.exit(1 if failures else 0)
