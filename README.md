# Better Word Format For Quarto

A Quarto Word format with a real title block: authors on one line with superscript affiliation numbers, a numbered affiliations list, a correspondence line, an optional logo, and a table of contents.

It works through a custom OpenXML template rather than a `reference-doc`, so it controls the structure of the document and not only its styles.

## Creating a New Document

```bash
quarto use template mcanouil/quarto-better-word@0.1.0
```

## Installation For Existing Document

```bash
quarto add mcanouil/quarto-better-word@0.1.0
```

This will install the extension under the `_extensions` subdirectory.
If you're using version control, you will want to check in this directory.

## Documentation

The full documentation lives at <https://m.canouil.dev/quarto-better-word/>: every option, the title block, how the template and its partials are put together, what an OpenXML template cannot do, and a document rendered by the site itself.

[`template.qmd`](template.qmd) is a complete starting point you can copy.

## Licence

[MIT](https://github.com/mcanouil/quarto-better-word?tab=MIT-1-ov-file#readme).
