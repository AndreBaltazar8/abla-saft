#!/usr/bin/env python3
"""Rebuilds each signed message from the XML, in this script's own code, and has openssl
verify it, sign it again to compare bytes, and reject it once tampered with. Then reads
the QR image with zbar. verify-signatures.py private.pem public.pem out"""
import base64
import os
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

private, public, folder = sys.argv[1:4]
N = "{urn:OECD:StandardAuditFile-Tax:PT_1.04_01}"
root = ET.parse(os.path.join(folder, "signed.xml")).getroot()
sources = root.find(N + "SourceDocuments")
tables = (
    ("SalesInvoices", "Invoice", "InvoiceNo", "InvoiceDate", "InvoiceType"),
    ("MovementOfGoods", "StockMovement", "DocumentNumber", "MovementDate", "MovementType"),
    ("WorkingDocuments", "WorkDocument", "DocumentNumber", "WorkDate", "WorkType"),
)
checked = tampered = identical = 0
failures = 0
temp = tempfile.mkdtemp()


def openssl_verify(message, signature):
    m = os.path.join(temp, "m")
    s = os.path.join(temp, "s")
    open(m, "wb").write(message)
    open(s, "wb").write(signature)
    return subprocess.run(["openssl", "dgst", "-sha1", "-verify", public, "-signature", s, m], capture_output=True).returncode == 0


def openssl_sign(message):
    m = os.path.join(temp, "m")
    s = os.path.join(temp, "s")
    open(m, "wb").write(message)
    subprocess.run(["openssl", "dgst", "-sha1", "-sign", private, "-out", s, m], check=True)
    return open(s, "rb").read()


for table, doc, number_tag, date_tag, type_tag in tables:
    section = sources.find(N + table)
    previous = {}
    for d in section.findall(N + doc):
        number = d.find(N + number_tag).text
        key = (d.find(N + type_tag).text, number.split("/")[0])
        message = ";".join([
            d.find(N + date_tag).text, d.find(N + "SystemEntryDate").text, number,
            d.find(f"{N}DocumentTotals/{N}GrossTotal").text, previous.get(key, ""),
        ]).encode()
        hash_text = d.find(N + "Hash").text
        signature = base64.b64decode(hash_text)
        if len(hash_text) != 172 or len(signature) != 128 or "\n" in hash_text:
            failures += 1
            print("FAIL: not 172 characters on one line:", number)
        if d.find(N + "HashControl").text != "1":
            failures += 1
            print("FAIL: HashControl", number)
        if not openssl_verify(message, signature):
            failures += 1
            print("FAIL: openssl rejected", number, message)
        checked += 1
        if openssl_sign(message) == signature:
            identical += 1
        else:
            failures += 1
            print("FAIL: openssl's signature differs", number)
        if openssl_verify(message + b"x", signature):
            failures += 1
            print("FAIL: openssl accepted a tampered message", number)
        else:
            tampered += 1
        previous[key] = hash_text
print(f"{checked} signatures verified by openssl on messages rebuilt from the XML; {identical} byte-identical to openssl's own; {tampered} tampered messages rejected; {failures} failures")

expected = open(os.path.join(folder, "qr-message.txt")).read()
for name in ("qr.png", "qr-big.png"):
    png = os.path.join(folder, name)
    done = subprocess.run(["zbarimg", "--quiet", "--raw", "-Sbinary", png], capture_output=True)
    read = done.stdout.decode("utf8", "replace").rstrip("\n")
    print(f"zbar on {name}: {'read the exact message' if read == expected else 'FAILED: ' + repr(read[:80])}")
    if read != expected and name == "qr-big.png":
        failures += 1
sys.exit(1 if failures else 0)
