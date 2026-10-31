# abla-saft

SAF-T (PT) 1.04_01 billing files for [Abla](https://github.com/AndreBaltazar8/ablac): a
typed model, a writer, a reader, checks, document signatures with their chain, ATCUD and
the QR code. Mozilla Public License 2.0.

**This isn't certified software and doesn't claim conformity with the Autoridade Tributária
e Aduaneira (AT).** Using it doesn't make a program certified: certification is AT's, for
a program, with a key declared to AT (Portaria 363/2010, articles 3 to 5). No file written
by this library has been through AT's validation. See [Not verified](#not-verified) and
[SOURCES.md](SOURCES.md), which says where each rule comes from and whether it was read.

```abla
import github("AndreBaltazar8/abla-saft")
import "abla/fs"

fun issue(file: SaftFile, invoice: SaftInvoice, signer: SaftSigner, previousHash: string): bool {
    val signature = saftSignInvoice(invoice, signer, previousHash)   // sets Hash and HashControl
    if (!signature.ok) return false
    val qr = saftQrForInvoice(file, invoice)
    if (!qr.ok) return false
    path("qr.png").writeText(saftQrImage(qr.message).png)
    val written = saftWrite(file)                                    // refuses a file with errors
    written.succeeded && path("saft.xml").writeText(written.text)
}
```

[examples/invoice.ab](examples/invoice.ab) is a whole program.

## Money

`SaftDecimal` is an exact decimal of any size, and the library has no float type anywhere
(`make test` greps for one). `dec("12.50")` for values in code, `saftDecimalParse` for input,
then `plus`, `minus`, `times`, `dividedBy(other, places, mode)`, `rounded(places, mode)`,
`compare`, `text()`, and `money()` for exactly two decimals. Modes: `saftRoundHalfUp` (the
default), `saftRoundHalfEven`, `saftRoundDown`.

## The file

`SaftFile(header, masterFiles, salesInvoices, movementOfGoods, workingDocuments, payments)`.
Field names follow the XSD, with optional text as `""` and optional amounts as `null`.

| Table | Types | Control totals from |
|---|---|---|
| 1 Header | `SaftHeader`, `SaftAddress` | |
| 2.2 to 2.5 MasterFiles | `SaftCustomer`, `SaftSupplier`, `SaftProduct`, `SaftTaxEntry` | |
| 4.1 SalesInvoices | `SaftInvoice`, `SaftLine`, `SaftDocumentTotals` | `saftSalesInvoices(invoices)` |
| 4.2 MovementOfGoods | `SaftStockMovement` | `saftMovementOfGoods(movements)` |
| 4.3 WorkingDocuments | `SaftWorkDocument` | `saftWorkingDocuments(documents)` |
| 4.4 Payments | `SaftPayment`, `SaftPaymentLine` | `saftPayments(payments)` |

The XSD's other document types are allowed too; these were tried: FT, FS, FR, ND, NC; GR, GT,
GA, GC, GD; CM, CC, FC, FO, NE, OU, OR, PF, DC; RC, RG. Accounting tables 2.1 and 3 aren't
modelled. The reader names them in `skippedTables`, and the writer leaves them out.

`saftComputeTotals(lines)` gives a document's tax, net and gross, in euros.
`saftEurosFromForeign(amount, rate)` converts, and `SaftCurrency` records the original.

`saftWrite(file, options)` returns `succeeded`, `text`, `issues`, `errorMessage`, and writes
Windows-1252 by default, as AT's schema and demonstration file do. `saftCheck(file)` lists
`SaftIssue`s (`severity`, `code`, `path`, `message`) on its own. An `error` is what the XSD
rejects, including its assertions, keys and uniqueness, or a wrong control total; `saftWrite`
refuses those. A `warning` is what the Portaria asks and the XSD can't see.

`saftRead(bytes, maxBytes)` returns `file`, `issues` and `error`. A misnamed element, a bad
number or a missing field is an issue, not a silent loss. It refuses a DTD and reads no
external entity. Reading isn't checking: follow it with `saftCheck` and `saftVerifyChains`.

## Signing

```abla
val made = saftRsaSignerFromPem(path("key.pem").readText(), version = 1)
val signer = made.signer                   // null on a bad key; made.error says why
val s = saftSignInvoice(invoice, signer, previousHash)
// s.ok, s.hash, s.hashControl, s.message, s.error
saftPrintedCharacters(invoice.hash)        // positions 1, 11, 21 and 31
saftProcessedByText(invoice.hash, 1234)    // "AxAx-Processado por programa certificado n.º 1234/AT"
```

- `previousHash` is the Hash of the last document of the same type and series, `""` for the first.
- `saftSignMovement` and `saftSignWorkDocument` are the same for tables 4.2 and 4.3. Receipts
  aren't signed. `saftSign(signer, date, entry, number, gross, previous)` signs bare fields.
- `SaftSigner` is an interface with `keyVersion()` and `sign(message)`, so a key can live
  in a device or service. `SaftRsaSigner` is the implementation here: RSA PKCS#1 v1.5 with
  SHA-1, as the Despacho requires, in pure Abla. **It isn't hardened** against timing or memory
  disclosure, and Despacho 3.1.4 requires the private key to be protected even while signing.
- Only 1024-bit keys are accepted: the Despacho fixes that size, and a larger signature
  wouldn't fit Hash's 172 characters.
- `saftVerifyChains(file, key)` walks every series. A changed field, a replaced Hash, a removed
  document and a Hash from another series are all caught. Without a key, only the sequence
  and the form can be checked. Removing the first documents of a file can't be seen from
  the file: those are counted in `unverifiable`, not passed as verified.
- `saftManualHashControl`, `saftDuplicateHashControl`, `saftIntegratedHashControl` give
  HashControl for recovered and integrated documents.

## ATCUD and QR code

- `saftAtcud(validationCode, documentNumber)` joins AT's code and the sequence number.
  Getting the code, by communicating the series to AT, is the program's job.
- `saftQrForInvoice`, `saftQrForMovement`, `saftQrForWorkDocument` and `saftQrForPayment`
  build the message from documents. `saftQrMessage(SaftQrData(...))` takes it field by field.
- `saftQrImage(message)` gives `png`, `svg` and `version` through
  [abla-qr](https://github.com/AndreBaltazar8/abla-qr): level M, byte mode, version 9 or more.
  The 30 x 30 mm minimum is the printed layout's to respect.

## Verified, with results

`make all`, run on 2026-10-31. CI runs the same checks on every push:

| Check | Result |
|---|---|
| Unit, golden and property tests (`make test`) | 6 programs, 33,915 checks, 0 failed |
| 25 golden files and 200 generated ones through the **official XSD** with [xmlschema](https://github.com/sissaschool/xmlschema), an XSD 1.1 processor | 225 valid, 0 errors |
| The same 225 through `xmllint`, on a copy of the XSD with what XSD 1.0 can't express removed (below) | 0 errors |
| 26 deliberately invalid files through the official XSD, and `saftCheck` | all rejected by both |
| Control totals of those files, recomputed in Python | 0 differences |
| 22 signatures with a throwaway key: messages rebuilt from the XML in Python, `openssl dgst -sha1 -verify` | all verified, byte-identical to openssl's own, all rejected once tampered with |
| Chain breaks (changed amount, replaced Hash, removed document, wrong series, restarts) | caught, by unit tests with an openssl-made key |
| AT's 7 specification examples, message by message | identical, with the QR version of each figure |
| QR PNG through this repository's sibling reader and [zbar](https://github.com/mchehab/zbar) | read exactly |
| 119,991 decimal operations against Python's `decimal` | 0 differences |
| AT's own demonstration file through the official XSD, reader, check and writer | 0 XSD errors, 0 check errors, control totals agree, 3,726 elements rewritten with 0 differences |

**xmllint can't load the official schema.** It declares `vc:minVersion="1.1"` and has 19
`xs:assert` and an `xs:all` with repeating elements, which libxml2 doesn't support. So the
official file goes through xmlschema untouched, and `tools/derive-xsd10.py` makes the copy for
xmllint. That copy loses the assertions, which xmlschema still checks. Any other program's
"validated with xmllint" against this schema isn't possible without a similar change.

The schema and texts aren't in this repository: `make sources` downloads them and checks
their hashes. SOURCES.md says why.

## Not verified

- **AT's validation.** No file has gone through it. No public validator was found. Secondary
  sources describe AT's check as happening when a taxpayer uploads a file to e-Fatura, which
  wasn't tried.
- **Signatures against AT.** AT has no key of this library's users, and its demonstration
  file's key isn't published, so the Hash values of AT's file weren't verified. openssl is the
  reference used, following the commands in the Despacho.
- **No certificate.** `R:` and `SoftwareCertificateNumber` are 0 in every test file. A real
  program needs AT's number.
- Everything listed as unconfirmed below.

### Unconfirmed rules

Each of these was decided here for lack of a text that says so, and could be wrong:

1. **Rounding mode.** The Despacho says "rounded off to two decimals" (2.6.7) without a mode. Half up here.
2. **Where tax is rounded.** `saftComputeTotals` rounds per rate within a document, not per
   line. No text read prescribes either. A program can pass its own totals.
3. **QR field Q on a receipt.** Marked mandatory, but receipts have no signature to take it
   from. `saftQrForPayment` writes `Q:0`; that value isn't in any text read.
4. **Taxes in a receipt's QR.** `saftQrForPayment` puts the net total in L, from the table's
   note on receipts "without tax discrimination". A receipt that does discriminate (RC) should
   use `saftQrMessage`.
5. **Windows-1252 as a requirement.** The XSD and AT's demonstration file are in it, and the
   Portaria names no encoding. An AT FAQ (faqs-00276) reportedly says so, but only a search
   summary of it could be seen: the page returned 404 when fetched.
6. **Exchange rate direction.** The Portaria doesn't give it. Multiplying is what AT's
   demonstration file does (317.45 USD x 0.74075 = 235.15 EUR), an example rather than a rule.
7. **Bytes signed for a number that isn't ASCII.** No text read settles it, so signing refuses one.
8. **The QR on uncertified programs.** Portaria 195/2020, article 6, requires it from programs
   certified by AT. What R holds without a certificate isn't said; this writes 0.
9. **Whether anything changed since the texts.** The XSD is dated 2022-05-17 and the QR
   specification 2020. Later amendments weren't searched exhaustively. The ATCUD's start date
   was reportedly postponed by later Despachos, seen only in secondary sources.
10. **VAT rates and exemption codes.** The library takes them as data and asserts none as
    current law. The rates in tests are examples. M codes are checked by form only: their list
    is in the "Manual de Integração de Software", not read.
11. **Diário da República originals.** Its site served no text to the tools used, so the
    Portarias were read in AT's consolidated copies, and the Despacho only in AT's unofficial
    English translation. Declaração de Retificação 2-A/2017 wasn't read separately.

## Tests

`make test` is the unit, golden and property tests. `make files`, `make signatures` and
`make at-demo` run the external checks above, taking their tools from Nix. A signing test
makes its key with openssl when it runs and removes it: no private key is in this repository,
and the golden files' Hash values come from a fake signer that no RSA key could verify.

## License

[Mozilla Public License 2.0](LICENSE), like its dependencies
[abla-xml](https://github.com/AndreBaltazar8/abla-xml) and abla-qr. The big integer code is adapted from
[abla-pdf](https://github.com/AndreBaltazar8/abla-pdf).
