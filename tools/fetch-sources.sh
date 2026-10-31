#!/usr/bin/env bash
# Downloads AT's schema, demonstration file and texts into .sources/, checked by hash.
# They aren't in this repository: SOURCES.md says why. If AT replaces a file, the hash
# fails loudly, and someone has to read what changed before updating the pin.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .sources
P=https://info.portaldasfinancas.gov.pt
fetch() {
    local name=$1 url=$2 sum=$3
    if [ ! -f ".sources/$name" ] || ! echo "$sum  .sources/$name" | sha256sum -c --quiet - 2>/dev/null; then
        curl -sS -L --fail -m 120 -A 'Mozilla/5.0 abla-saft' -o ".sources/$name" "$url"
    fi
    echo "$sum  .sources/$name" | sha256sum -c --quiet -
}
while read -r name sum url; do
    [ -z "$name" ] || fetch "$name" "$P$url" "$sum"
done < tools/sources.txt
