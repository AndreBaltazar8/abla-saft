#!/usr/bin/env python3
"""The official XSD on a file small enough to load. Usage: validate-sample.py official.xsd file"""
import resource
import sys

import xmlschema

schema = xmlschema.XMLSchema11(sys.argv[1])
errors = 0
for error in schema.iter_errors(sys.argv[2]):
    errors += 1
    if errors <= 5:
        print("error:", error.reason, "at", error.path)
print(f"xmlschema {xmlschema.__version__}, official XSD: {errors} errors, peak {resource.getrusage(resource.RUSAGE_SELF).ru_maxrss} kB")
sys.exit(1 if errors else 0)
