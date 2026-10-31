#!/usr/bin/env python3
"""Reads tools/decimal-vectors.ab's output on stdin and recomputes each with Python's decimal."""
import sys
from decimal import Decimal as D, getcontext, ROUND_HALF_UP, ROUND_HALF_EVEN, ROUND_DOWN

getcontext().prec = 400
MODES = [ROUND_HALF_UP, ROUND_HALF_EVEN, ROUND_DOWN]
count = bad = 0
for row in sys.stdin:
    f = row.split()
    op = f[0]
    if op == "add":
        same = D(f[1]) + D(f[2]) == D(f[3])
    elif op == "sub":
        same = D(f[1]) - D(f[2]) == D(f[3])
    elif op == "mul":
        same = D(f[1]) * D(f[2]) == D(f[3])
    elif op == "cmp":
        same = ((D(f[1]) > D(f[2])) - (D(f[1]) < D(f[2]))) == int(f[3])
    elif op == "round":
        same = D(f[1]).quantize(D(1).scaleb(-int(f[2])), MODES[int(f[3])]) == D(f[4])
    elif op == "div":
        same = (D(f[1]) / D(f[2])).quantize(D(1).scaleb(-int(f[3])), MODES[int(f[4])]) == D(f[5])
    else:
        raise SystemExit("unknown: " + row)
    count += 1
    if not same:
        bad += 1
        if bad < 10:
            print("DIFFERS", row.strip())
print(f"{count} decimal operations agree with Python's decimal; {bad} differ")
sys.exit(1 if bad or not count else 0)
