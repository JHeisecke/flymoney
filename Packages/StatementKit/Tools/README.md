# Tools

## `scrub.swift` — fixture generator

Turns a bank PDF into a scrubbed `[TextPage]` JSON fixture for `StatementParsingTests`.

```bash
swift scrub.swift <input.pdf> <output.json> <terms.json>
```

The output is the same flat positioned-word geometry `PDFKitStatementTextExtractor`
produces: glyphs grouped into baselines at a fixed 1.5pt tolerance, split into words
on space glyphs or a >2.5pt horizontal gap, coordinates rounded to 2dp. Row banding is
*not* applied — that needs a profile's `yTolerance` and is a parsing step.

### The terms file is not in this repository, on purpose

A deny-list scrubber has to contain the exact strings it redacts. Committing the term
list would publish a tidy, labelled inventory of precisely the data the fixtures were
cleaned of — worse than never scrubbing at all, because it is easier to read than the
original document.

So the terms live **beside the source PDFs, outside the repo**. Neither the PDFs nor
the terms are ever committed; the fixtures they produce are.

The tool **refuses to run** without a readable terms file rather than falling back to
pass-through. Emitting unredacted geometry is the one outcome it must never have.

### Terms file format

```json
{
  "minimumDigitRunLength": 11,
  "literals": {
    "SURNAME": "SAMPLENAME",
    "4111111111111111": "4111111111111111"
  }
}
```

- **`literals`** — case- and diacritic-insensitive substring replacements. Each
  replacement is padded (`X`) or truncated to the **original's length**, so word bounds
  stay coherent with their text. Longest needle wins, so a full card number is replaced
  before its four-digit groups are.
- **`minimumDigitRunLength`** — structural backstop: any bare digit run at least this
  long is zeroed, catching account and barcode numbers no one thought to list. Amounts
  always carry a grouping separator in these documents, so they are untouched.

Cover names (including any bank employee's), card and account numbers in every spacing
variant, phone numbers, address tokens, and barcode payloads — those often encode the
card number.

### After regenerating

Sweep the output for every term before committing it:

```bash
grep -oiE 'SURNAME|4111111111111111|…' *.json    # must return nothing
```

Regenerating the three GNB fixtures from the same PDFs and terms reproduces the
committed files **byte for byte** — if a diff appears, the tool or its inputs changed,
and that is worth understanding before the fixture is updated.
