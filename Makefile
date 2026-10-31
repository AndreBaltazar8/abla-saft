ABLAC_DIR ?= $(abspath ../ablac)
COMPILER ?= $(ABLAC_DIR)/build/ablac
TESTS := tests/decimal_test.ab tests/writer_test.ab tests/reader_test.ab tests/sign_test.ab tests/qr_test.ab tests/property_test.ab
BUILD := nix-shell $(ABLAC_DIR)/shell.nix --run
TOOLS := nix-shell -p libxml2 openssl zbar 'python3.withPackages(p: [p.xmlschema])' --run
GENERATED ?= 200

.PHONY: test test-in-shell sources programs programs-in-shell files signatures at-demo codes all clean

all: test files signatures at-demo

test:
	$(BUILD) '$(MAKE) test-in-shell'

# Money never goes through floats: no float type in the library at all.
test-in-shell:
	$(COMPILER) package update --project . >/dev/null
	! grep -nE '\b(f32|f64)\b|abla/float' src/*.ab
	$(COMPILER) test $(TESTS)

sources:
	tools/fetch-sources.sh

programs:
	$(BUILD) '$(MAKE) programs-in-shell'

programs-in-shell:
	$(COMPILER) package update --project . >/dev/null
	$(COMPILER) build examples/invoice.ab -o build/invoice
	$(COMPILER) build tools/make-files.ab -o build/make-files
	$(COMPILER) build tools/sign-series.ab -o build/sign-series
	$(COMPILER) build tools/at-demo.ab -o build/at-demo
	$(COMPILER) build tools/decimal-vectors.ab -o build/decimal-vectors

# Every document type and generated files, through the official XSD and xmllint.
files: sources programs
	$(TOOLS) 'tools/check-all.sh $(GENERATED)'

# Signatures with a key made on the spot, against openssl, and the QR image through zbar.
signatures: programs
	$(TOOLS) tools/check-signatures.sh

# AT's own demonstration file through the reader, checks and the writer.
at-demo: sources programs
	$(TOOLS) tools/check-at-demo.sh

codes: sources
	python3 -I tools/gen-codes.py .sources/saftpt1.04_01.xsd > src/codes.ab

clean:
	rm -rf build
