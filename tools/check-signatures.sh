#!/usr/bin/env bash
# Makes a throwaway RSA key, signs with build/sign-series and verifies with openssl. The key
# lives in a temporary directory removed on exit, and is never committed.
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
openssl genrsa -out "$work/PrivateKey.pem" 1024 2>/dev/null
openssl rsa -in "$work/PrivateKey.pem" -out "$work/PublicKey.pem" -outform PEM -pubout 2>/dev/null
build/sign-series "$work/PrivateKey.pem" "$work/out"
tools/verify-signatures.sh "$work/PrivateKey.pem" "$work/PublicKey.pem" "$work/out"
# The verifier must fail on a file that is wrong in one place: a total, a date, a signature.
mutant() {
    rm -rf "$work/mutant"
    cp -r "$work/out" "$work/mutant"
    "$2" "$work/mutant/signed.xml" > "$work/mutant/changed.xml"
    cmp -s "$work/mutant/changed.xml" "$work/mutant/signed.xml" && { echo "FAIL: mutation '$1' changed nothing"; exit 1; }
    mv "$work/mutant/changed.xml" "$work/mutant/signed.xml"
    if tools/verify-signatures.sh "$work/PrivateKey.pem" "$work/PublicKey.pem" "$work/mutant" > "$work/mutant.txt" 2>&1; then
        echo "FAIL: the verifier accepted a file with $1"
        exit 1
    fi
    echo "the verifier refuses a file with $1: $(grep -c FAIL "$work/mutant.txt") failures"
}
wrong_total() { sed '0,/<GrossTotal>/s//<GrossTotal>1/' "$1"; }
wrong_date() { sed '0,/<InvoiceDate>2026/s//<InvoiceDate>2025/' "$1"; }
wrong_signature() { awk '!d && match($0, /<Hash>./) { c = substr($0, RSTART + 6, 1); $0 = substr($0, 1, RSTART + 5) (c == "A" ? "B" : "A") substr($0, RSTART + 7); d = 1 } { print }' "$1"; }
mutant "a wrong GrossTotal" wrong_total
mutant "a wrong InvoiceDate" wrong_date
mutant "a changed first character of a signature" wrong_signature
echo "PKCS#8 key form:"
openssl pkcs8 -topk8 -nocrypt -in "$work/PrivateKey.pem" -out "$work/pkcs8.pem"
build/sign-series "$work/pkcs8.pem" "$work/out8"
cmp "$work/out/signed.xml" "$work/out8/signed.xml" && echo "same bytes from PKCS#1 and PKCS#8"
if openssl genrsa -out "$work/big.pem" 2048 2>/dev/null && build/sign-series "$work/big.pem" "$work/outbig" 2>/dev/null; then
    echo "FAIL: a 2048-bit key was accepted"
    exit 1
fi
echo "a 2048-bit key is refused"
