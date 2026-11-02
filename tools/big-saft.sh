#!/usr/bin/env bash
# A SAF-T file of at least 3 GiB written, checked and read back through files, with each
# program's peak memory, then copied through the streams and compared byte for byte, and
# validated whole against the official XSD 1.1, streaming, by build/saft-xsd. Every control
# total is also recomputed over the whole file in Python. Local only. Removes its files, also on
# failure.
#   tools/big-saft.sh <big-saft program> <directory> [documents] [official xsd]
set -euo pipefail
program=$1
directory=$2
documents=${3:-530000}
official=${4:-.sources/saftpt1.04_01.xsd}
validator=${SAFT_XSD:-build/saft-xsd}
python=${PYTHON:-python3}
tools=$(cd "$(dirname "$0")" && pwd)
file=$(mktemp "$directory/abla-saft-big.XXXXXX")
copy=$(mktemp "$directory/abla-saft-copy.XXXXXX")
bad=$(mktemp "$directory/abla-saft-bad.XXXXXX")
trap 'rm -f "$file" "$copy" "$bad"' EXIT
time=${TIME_BIN:-/usr/bin/time}
"$time" -f 'write: %e s, peak %M kB' "$program" write "$file" "$documents"
ls -l "$file"
"$time" -f 'read, every check: %e s, peak %M kB' "$program" read "$file"
"$time" -f 'read and copy: %e s, peak %M kB' "$program" read "$file" "$copy"
cmp "$file" "$copy"
echo 'the copy is byte-identical'
sha256sum "$file" | cut -c1-16
rm -f "$copy"
"$time" -f 'the official XSD 1.1, whole file: %e s, peak %M kB' "$validator" "$official" "$file"
"$time" -f 'recomputing totals in Python: %e s, peak %M kB' "$python" -I "$tools/check-big.py" "$file" /dev/null 1000000000
if "$time" -f 'a wrong total: %e s, peak %M kB' "$program" bad-total "$bad" "$documents"; then
    echo 'a wrong total was NOT refused'
    exit 1
fi
echo 'a wrong total was refused'
