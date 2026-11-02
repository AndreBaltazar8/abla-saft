#!/usr/bin/env python3
"""Recomputes, independently, the control totals of every file in valid/ of a directory made by
tools/make-files.ab. Whether they pass the official XSD, and the files in invalid/ fail it, is
build/saft-xsd's, in tools/check-all.sh. Usage: check-files.py dir"""
import glob
import os
import sys
from decimal import Decimal, ROUND_HALF_UP
import xml.etree.ElementTree as ET

folder = sys.argv[1]
N = "{urn:OECD:StandardAuditFile-Tax:PT_1.04_01}"
failures = 0


def fail(message):
    global failures
    failures += 1
    print("FAIL", message)


def sums(section, doc, status_name, excluded):
    debit = credit = Decimal(0)
    documents = section.findall(N + doc)
    for d in documents:
        if d.find(f"{N}DocumentStatus/{N}{status_name}").text in excluded:
            continue
        for line in d.findall(N + "Line"):
            a = line.find(N + "DebitAmount")
            b = line.find(N + "CreditAmount")
            if a is not None:
                debit += Decimal(a.text)
            if b is not None:
                credit += Decimal(b.text)
    return len(documents), debit, credit


def check_totals(path):
    root = ET.parse(path).getroot()
    sources = root.find(N + "SourceDocuments")
    if sources is None:
        return
    for name, doc, status, excluded in (
        ("SalesInvoices", "Invoice", "InvoiceStatus", ("A", "F")),
        ("WorkingDocuments", "WorkDocument", "WorkStatus", ("A",)),
        ("Payments", "Payment", "PaymentStatus", ("A",)),
    ):
        section = sources.find(N + name)
        if section is None:
            continue
        count, debit, credit = sums(section, doc, status, excluded)
        if int(section.find(N + "NumberOfEntries").text) != count:
            fail(f"{path}: {name} NumberOfEntries")
        if Decimal(section.find(N + "TotalDebit").text) != debit:
            fail(f"{path}: {name} TotalDebit {section.find(N + 'TotalDebit').text} != {debit}")
        if Decimal(section.find(N + "TotalCredit").text) != credit:
            fail(f"{path}: {name} TotalCredit {section.find(N + 'TotalCredit').text} != {credit}")
    goods = sources.find(N + "MovementOfGoods")
    if goods is not None:
        lines = quantity = 0
        for d in goods.findall(N + "StockMovement"):
            for line in d.findall(N + "Line"):
                lines += 1
                if d.find(f"{N}DocumentStatus/{N}MovementStatus").text != "A":
                    quantity += Decimal(line.find(N + "Quantity").text)
        if int(goods.find(N + "NumberOfMovementLines").text) != lines:
            fail(f"{path}: NumberOfMovementLines")
        if Decimal(goods.find(N + "TotalQuantityIssued").text) != quantity:
            fail(f"{path}: TotalQuantityIssued")
    # Document totals: GrossTotal = NetTotal + TaxPayable, NetTotal = |credit - debit| at 2 places.
    for doc in ("SalesInvoices/" + N + "Invoice", "WorkingDocuments/" + N + "WorkDocument", "MovementOfGoods/" + N + "StockMovement"):
        for d in sources.findall(N + doc):
            totals = d.find(N + "DocumentTotals")
            net = Decimal(totals.find(N + "NetTotal").text)
            tax = Decimal(totals.find(N + "TaxPayable").text)
            gross = Decimal(totals.find(N + "GrossTotal").text)
            if net + tax != gross:
                fail(f"{path}: {d[0].text} gross")
            base = Decimal(0)
            for line in d.findall(N + "Line"):
                if line.find(N + "CreditAmount") is not None:
                    base += Decimal(line.find(N + "CreditAmount").text)
                else:
                    base -= Decimal(line.find(N + "DebitAmount").text)
            if abs(base).quantize(Decimal("0.01"), ROUND_HALF_UP) != net:
                fail(f"{path}: {d[0].text} net {net} != {base}")


valid = sorted(glob.glob(os.path.join(folder, "valid", "*.xml")))
invalid = sorted(glob.glob(os.path.join(folder, "invalid", "*.xml")))
if not valid or not invalid:
    raise SystemExit("nothing to check")
for path in valid:
    check_totals(path)
print(f"control totals of {len(valid)} valid files recomputed; {failures} failures")
sys.exit(1 if failures else 0)
