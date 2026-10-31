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
python3 tools/verify-signatures.py "$work/PrivateKey.pem" "$work/PublicKey.pem" "$work/out"
echo "PKCS#8 key form:"
openssl pkcs8 -topk8 -nocrypt -in "$work/PrivateKey.pem" -out "$work/pkcs8.pem"
build/sign-series "$work/pkcs8.pem" "$work/out8"
cmp "$work/out/signed.xml" "$work/out8/signed.xml" && echo "same bytes from PKCS#1 and PKCS#8"
if openssl genrsa -out "$work/big.pem" 2048 2>/dev/null && build/sign-series "$work/big.pem" "$work/outbig" 2>/dev/null; then
    echo "FAIL: a 2048-bit key was accepted"
    exit 1
fi
echo "a 2048-bit key is refused"
