#!/usr/bin/env bash
# Has openssl verify each signed message that build/signed-messages rebuilt from the XML,
# sign it again to compare bytes, and reject it once tampered with. Then reads the QR
# image with zbar. Needs openssl, base64 and zbarimg.
#   tools/verify-signatures.sh private.pem public.pem out
set -uo pipefail
private=$1
public=$2
folder=$3
messages=${SIGNED_MESSAGES:-build/signed-messages}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
checked=0
tampered=0
identical=0
failures=0

rows=$("$messages" "$folder/signed.xml") || failures=$((failures + 1))
while IFS=$'\t' read -r number message hash; do
    [ -n "$number" ] || continue
    printf '%s' "$message" > "$work/m"
    printf '%s' "$hash" | base64 -d > "$work/s" 2>/dev/null || true
    if [ "$(wc -c < "$work/s")" -ne 128 ]; then
        failures=$((failures + 1))
        echo "FAIL: not a 128-byte signature: $number"
    fi
    if ! openssl dgst -sha1 -verify "$public" -signature "$work/s" "$work/m" >/dev/null 2>&1; then
        failures=$((failures + 1))
        echo "FAIL: openssl rejected $number $message"
    fi
    checked=$((checked + 1))
    openssl dgst -sha1 -sign "$private" -out "$work/own" "$work/m"
    if cmp -s "$work/own" "$work/s"; then
        identical=$((identical + 1))
    else
        failures=$((failures + 1))
        echo "FAIL: openssl's signature differs $number"
    fi
    printf '%sx' "$message" > "$work/t"
    if openssl dgst -sha1 -verify "$public" -signature "$work/s" "$work/t" >/dev/null 2>&1; then
        failures=$((failures + 1))
        echo "FAIL: openssl accepted a tampered message $number"
    else
        tampered=$((tampered + 1))
    fi
done <<<"$rows"
[ "$checked" -gt 0 ] || { failures=$((failures + 1)); echo "FAIL: no signed document"; }
echo "$checked signatures verified by openssl on messages rebuilt from the XML; $identical byte-identical to openssl's own; $tampered tampered messages rejected; $failures failures"

expected=$(cat "$folder/qr-message.txt")
for name in qr.png qr-big.png; do
    read=$(zbarimg --quiet --raw -Sbinary "$folder/$name" 2>/dev/null) || true
    if [ "$read" = "$expected" ]; then
        echo "zbar on $name: read the exact message"
    else
        echo "zbar on $name: FAILED: ${read:0:80}"
        [ "$name" = qr-big.png ] && failures=$((failures + 1))
    fi
done
[ "$failures" -eq 0 ]
