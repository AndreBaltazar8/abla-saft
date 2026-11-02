ABLAC_DIR ?= $(abspath ../ablac)
COMPILER ?= $(ABLAC_DIR)/build/ablac
TESTS := tests/decimal_test.ab tests/writer_test.ab tests/reader_test.ab tests/sign_test.ab tests/qr_test.ab tests/property_test.ab tests/stream_test.ab tests/xsd_test.ab
BUILD := nix-shell $(ABLAC_DIR)/shell.nix --run
TOOLS := nix-shell -p openssl zbar python3 --run
GENERATED ?= 200

.PHONY: big test test-in-shell sources programs programs-in-shell files signatures at-demo codes xsd-expected all clean

all: test files signatures at-demo

test: sources
	$(BUILD) '$(MAKE) test-in-shell'

# Money never goes through floats: no float type in the library at all. tests/xsd_test.ab needs
# the official XSD, from `make sources`.
test-in-shell:
	$(COMPILER) package update --project . >/dev/null
	! grep -nE '\b(f32|f64)\b|abla/float' src/*.ab src/xsd/*.ab
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
	$(COMPILER) build tools/saft-xsd.ab -o build/saft-xsd

# Every document type and generated files, through the official XSD (build/saft-xsd).
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

# What xmlschema, an independent XSD 1.1 validator, says of tests/xsd/mutations.txt, which
# tests/xsd_test.ab compares with. Run after changing the corpus.
xsd-expected: sources
	nix-shell -p 'python3.withPackages(p: [p.xmlschema p.lxml])' --run 'python3 -I tools/xsd-expected.py .sources/saftpt1.04_01.xsd' > tests/xsd/expected.txt

# A SAF-T file of at least 3 GiB through files, with peak memory. Local only; needs GNU time.
BIG_DIR ?= /tmp
big: sources programs
	$(COMPILER) build tools/big-saft.ab -o build/big-saft
	$(TOOLS) 'tools/big-saft.sh build/big-saft $(BIG_DIR)'

clean:
	rm -rf build
