#!/usr/bin/env bash
# Reads tools/decimal-vectors.ab's output on stdin and recomputes each operation with GNU bc,
# an independent arbitrary-precision implementation: add, sub, mul and cmp exactly; round and
# div to a number of places with the mode of the row (0 half up, 1 half even, 2 down, as in
# src/decimal.ab). Values are compared as numbers, so 1.50 and 1.5 are the same. A division is
# rounded from its exact quotient and remainder, with no intermediate rounding.
#   build/decimal-vectors 20000 | tools/check-decimals.sh
#   tools/check-decimals.sh --self-test     rows made wrong on purpose must each be reported
# Needs bc and awk.
set -euo pipefail
export BC_LINE_LENGTH=0

prelude='scale = 400
/* The integer n/d truncated, for n >= 0 and d > 0, rounded by mode m: 0 half up, 1 half even,
   2 down. i is the truncated quotient, rem what is left, and c compares twice it with d. */
define q(n, d, m) {
    auto s, i, rem, c, o
    s = scale
    scale = 0
    i = n / d
    o = i % 2
    scale = s
    rem = n - i * d
    c = (2 * rem > d) - (2 * rem < d)
    if (m == 2) return i
    if (m == 0) return i + (c >= 0)
    return i + (c > 0 || (c == 0 && o == 1))
}
define r(x, p, m) {
    auto g
    g = 1
    if (x < 0) { g = -1; x = -x }
    return g * q(x * 10 ^ p, 1, m) / 10 ^ p
}
define v(x, y, p, m) {
    auto g
    g = 1
    if (x < 0) { g = -g; x = -x }
    if (y < 0) { g = -g; y = -y }
    return g * q(x * 10 ^ p, y, m) / 10 ^ p
}'

check() {
    {
        echo "$prelude"
        awk '
        function number(s) { return s ~ /^-?[0-9]+(\.[0-9]+)?$/ }
        function whole(s) { return s ~ /^[0-9]+$/ }
        function bad(why) { print "unknown or malformed row " NR ": " $0 > "/dev/stderr"; exit 2 }
        {
            row = $0
            gsub(/"/, "", row)
            n = NF
            if ($1 == "add" || $1 == "sub" || $1 == "mul") {
                if (n != 4 || !number($2) || !number($3) || !number($4)) bad()
                op = ($1 == "add") ? "+" : ($1 == "sub" ? "-" : "*")
                expr = "(" $2 ") " op " (" $3 ")"; want = "(" $4 ")"
            } else if ($1 == "cmp") {
                if (n != 4 || !number($2) || !number($3) || $4 !~ /^-?[01]$/) bad()
                expr = "((" $2 ") > (" $3 ")) - ((" $2 ") < (" $3 "))"; want = $4
            } else if ($1 == "round") {
                if (n != 5 || !number($2) || !whole($3) || $4 !~ /^[012]$/ || !number($5)) bad()
                expr = "r(" $2 ", " $3 ", " $4 ")"; want = "(" $5 ")"
            } else if ($1 == "div") {
                if (n != 6 || !number($2) || !number($3) || !whole($4) || $5 !~ /^[012]$/ || !number($6)) bad()
                expr = "v(" $2 ", " $3 ", " $4 ", " $5 ")"; want = "(" $6 ")"
            } else bad()
            rows++
            print "if ((" expr ") != " want ") print \"DIFFERS " row "\\n\""
        }
        END { print "print \"ROWS " rows + 0 "\\n\"" }' || return 2
    } | bc -q
}

report() {
    local out rows bad
    out=$(check) || return 2
    rows=$(sed -n 's/^ROWS //p' <<<"$out")
    bad=$(grep -c '^DIFFERS' <<<"$out" || true)
    grep '^DIFFERS' <<<"$out" | head -9 || true
    echo "$rows decimal operations agree with bc; $bad differ"
    [ "$bad" -eq 0 ] && [ "$rows" -gt 0 ]
}

if [ "${1:-}" = "--self-test" ]; then
    # Right rows, each a case that has gone wrong in a decimal library: ties in every mode,
    # negative ties, a quotient that is only just under a tie, carries, zero.
    good='add 0.1 0.2 0.3
add -5 3 -2
sub 1 1.001 -0.001
mul -12.5 0.04 -0.500
mul 99999999999999999999 99999999999999999999 9999999999999999999800000000000000000001
cmp 1.50 1.5 0
cmp -2 -1 -1
cmp 0.000000000001 0 1
round 2.5 0 0 3
round 2.5 0 1 2
round 3.5 0 1 4
round 2.5 0 2 2
round -2.5 0 0 -3
round -2.5 0 1 -2
round -2.5 0 2 -2
round 0.125 2 0 0.13
round 0.125 2 1 0.12
round 0.135 2 1 0.14
round 0.1249999 2 0 0.12
round 9.995 2 0 10.00
round -0.004 2 0 0
div 1 3 4 0 0.3333
div 2 3 4 0 0.6667
div 2 3 4 2 0.6666
div 1 8 2 0 0.13
div 1 8 2 1 0.12
div 3 8 2 1 0.38
div -1 8 2 0 -0.13
div 1 -8 2 2 -0.12
div 1 3 0 0 0
div 5 2 0 1 2
div 7 2 0 1 4
div 0.5 0.25 0 2 2'
    if ! report <<<"$good" >/dev/null; then
        echo "FAIL: self-test: right rows were reported as wrong"
        report <<<"$good" || true
        exit 1
    fi
    # The same rows with one result changed each: every one must be reported.
    wrong=$(awk '
        $1 == "cmp" { $NF = ($NF == 0) ? 1 : 0 }
        $1 != "cmp" { $NF = $NF (index($NF, ".") ? "1" : ".5") }
        { print }' <<<"$good")
    count=$(grep -c . <<<"$wrong")
    differing=$(check <<<"$wrong" | grep -c '^DIFFERS' || true)
    if [ "$differing" -ne "$count" ]; then
        echo "FAIL: self-test: $differing of $count wrong rows reported"
        exit 1
    fi
    echo "decimal oracle self-test: $count right rows agree, the same $count with a wrong result all differ"
    exit 0
fi

report
