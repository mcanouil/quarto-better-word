# Better Word

A Quarto format for Word (`.docx`) output that customises the document structure through a custom OpenXML Pandoc template, going beyond what a `reference-doc` alone can achieve.

It builds a journal-style title block from Quarto's author and affiliation metadata, keeps landscape sections in sync with the base page size, and demonstrates structural front-matter customisation in the spirit of the HTML and Typst templates.
See the upstream discussion for background: [quarto-dev/discussions/14695](https://github.com/orgs/quarto-dev/discussions/14695).

## Installation

```bash
quarto add mcanouil/quarto-better-word
```

This will install the extension under the `_extensions` subdirectory.
If you are using version control, you will want to check in this directory.

## Usage

To use the extension, add the following to your document's front matter:

```yaml
format:
  better-word-docx: default
```

The title block is built from the standard Quarto [author and affiliation schema](https://quarto.org/docs/journals/authors.html#author-metadata):

```yaml
author:
  - name:
      given: Ada
      family: Lovelace
    orcid: 0000-0000-0000-0000
    email: ada@example.org
    corresponding: true
    affiliations:
      - ref: inst
affiliations:
  - id: inst
    name: Example Institute
    city: London
    country: United Kingdom
```

### Configuration

| Option                  | Type    | Default | Description                                            |
| ----------------------- | ------- | ------- | ------------------------------------------------------ |
| `toc`                   | boolean | `true`  | Include a table of contents.                           |
| `docx-page-width`       | integer | `11906` | Base page width in twips (A4 portrait).                |
| `docx-page-height`      | integer | `16838` | Base page height in twips (A4 portrait).               |
| `docx-page-margin`      | integer | `1440`  | Margin on all four sides in twips (1in).               |
| `docx-title-page-break` | boolean | `false` | Insert a page break after the title block.             |

Page geometry is expressed in twips (1/1440 inch): A4 is `11906 x 16838`, US Letter is `12240 x 15840`.

## Customising

The format wires a custom OpenXML template through Pandoc's `template:` option, set in [`_extensions/better-word/_extension.yml`](_extensions/better-word/_extension.yml).
Pandoc 3.2.1+ supports `--template` for `.docx` output using the OpenXML format.
Unlike a `reference-doc`, which only controls styles, a custom template controls the document structure itself.

The template lives at [`_extensions/better-word/template.xml`](_extensions/better-word/template.xml) and is based on Pandoc's [`default.openxml`](https://github.com/jgm/pandoc/blob/main/data/templates/default.openxml).
It is split into a main skeleton plus partials, mirroring Quarto's own template layout for other formats: [`title-block.xml`](_extensions/better-word/title-block.xml) holds the front matter (logo, title, authors, affiliations, correspondence, date, abstract) and [`toc.xml`](_extensions/better-word/toc.xml) holds the table of contents and the list-of-figures/tables blocks.
Pandoc resolves the `$title-block.xml()$` and `$toc.xml()$` calls in the directory containing the main template; Quarto's `template-partials` option does not apply to `docx`.

### Capability boundary

The template renders **only** `word/document.xml`.
It can emit any WordprocessingML content (paragraphs, runs, direct `w:pPr`/`w:rPr` formatting, tables, fields, section properties), but it cannot create or modify other package parts.
Styles (`styles.xml`), headers and footers (`header1.xml`/`footer1.xml`), media, and relationships all come from Pandoc and the reference document.
The template therefore *applies* styles and layers direct formatting, but it does not *define* styles, and it cannot add running headers or footers on its own.

### Title block

The title block iterates a plain-string author model (`docx-by-author` / `docx-by-affiliation`, built by the filter from Quarto's normalised `by-author` / `by-affiliation`) to render authors on one line with superscript affiliation numbers, a superscript corresponding-author marker, a numbered affiliations list, and a correspondence line with the corresponding author's email and ORCID.
A centred title logo is rendered from the `title-logo` metadata when it is set to a markdown image, for example `title-logo: '![](logo.svg){height=2cm}'`; Pandoc emits the image part and relationship automatically.

### Page size and landscape sections

Word section breaks do not inherit page properties, so each section must define its own.
Quarto's built-in landscape filter injects an empty section break before a `.landscape` div (which drops the preceding section's page size and margins) and a landscape break with hardcoded A4 dimensions after it (see [issue #12917](https://github.com/quarto-dev/quarto-cli/issues/12917) and [PR #12921](https://github.com/quarto-dev/quarto-cli/pull/12921)).

This extension defines the page geometry once as the shared `docx-page-width` / `docx-page-height` / `docx-page-margin` metadata.
The [`landscape-page-size.lua`](_extensions/better-word/landscape-page-size.lua) filter builds every section break from those values: it sets the base `w:sectPr` (passed to the template through the `docx-sectpr` variable), and it wraps each `.landscape` div in its own section breaks before the built-in filter runs, so the built-in filter's empty and hardcoded breaks are never emitted.
The preceding portrait section keeps its size and margins, and the landscape section uses the base geometry with width and height swapped.

## Limitations

- Setting the page geometry metadata replaces the reference document's section properties, including any header or footer references it carries; the two are mutually exclusive.
- Running headers and footers, watermarks, and named styles require a reference document; they cannot be produced from the template alone.
- Quarto does not expose `_brand.yml` values to the docx OpenXML template, so branding is applied through a reference document rather than template variables.
- The table of contents is inserted without the auto-update flag, so Word does not prompt to update fields on open; update the field manually (`F9`, or right-click then *Update Field*) to populate the entries and page numbers.

## Example

Here is the source code for a minimal example: [template.qmd](template.qmd).

Output of `template.qmd`:

- [DOCX](https://m.canouil.dev/quarto-better-word/template.docx).
