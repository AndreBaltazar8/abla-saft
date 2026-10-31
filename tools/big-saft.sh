#!/usr/bin/env bash
# A SAF-T file of at least 3 GiB written, checked and read back through files, with each
# program's peak memory, then copied through the streams and compared byte for byte, and
# put through xmllint's streaming validator on the XSD 1.0 copy. Local only. Removes its
# files, also on failure. xmlschema's lazy mode fails on this schema's identity constraints
# (KeyError in iter_errors), and it does about 1 MB/s, so every control total is recomputed
# over the whole file in Python and a sample of its documents goes through the official XSD.
#   tools/big-saft.sh <big-saft program> <directory> [documents] [derived xsd] [official xsd]
set -euo pipefail
program=$1
directory=$2
documents=${3:-530000}
xsd=${4:-build/saftpt-xsd10.xsd}
official=${5:-.sources/saftpt1.04_01.xsd}
python=${PYTHON_XMLSCHEMA:-python3}
tools=$(cd "$(dirname "$0")" && pwd)
sample=$(mktemp "$directory/abla-saft-sample.XXXXXX")
file=$(mktemp "$directory/abla-saft-big.XXXXXX")
copy=$(mktemp "$directory/abla-saft-copy.XXXXXX")
bad=$(mktemp "$directory/abla-saft-bad.XXXXXX")
trap 'rm -f "$file" "$copy" "$bad" "$sample"' EXIT
time=${TIME_BIN:-/usr/bin/time}
"$time" -f 'write: %e s, peak %M kB' "$program" write "$file" "$documents"
ls -l "$file"
"$time" -f 'read, every check: %e s, peak %M kB' "$program" read "$file"
"$time" -f 'read and copy: %e s, peak %M kB' "$program" read "$file" "$copy"
cmp "$file" "$copy"
echo 'the copy is byte-identical'
sha256sum "$file" | cut -c1-16
rm -f "$copy"
"$time" -f 'xmllint --stream --schema: %e s, peak %M kB' xmllint --stream --noout --huge --nonet --schema "$xsd" "$file"
"$time" -f 'recomputing totals in Python: %e s, peak %M kB' "$python" -I "$tools/check-big.py" "$file" "$sample" 100
ls -l "$sample"
"$time" -f 'xmlschema on the 1%% sample: %e s, peak %M kB' "$python" -I "$tools/validate-sample.py" "$official" "$sample"
rm -f "$sample"
if "$time" -f 'a wrong total: %e s, peak %M kB' "$program" bad-total "$bad" "$documents"; then
    echo 'a wrong total was NOT refused'
    exit 1
fi
echo 'a wrong total was refused'
