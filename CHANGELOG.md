# Changelog

## Unreleased

- feat: Add categories, description, modified date, DOI, and keywords to the title block, matching the fields Quarto's HTML title block exposes.
- feat: Render the DOI, ORCID, and email as clickable field-code hyperlinks, which need no document relationship entry.
- feat: Localise the published, modified, and keywords headings via Quarto's `labels` metadata so they follow the document language (Quarto provides no translation for the DOI heading).
- refactor: Split the front matter into a `title-block.xml` and a `title-metadata.xml` partial, mirroring Quarto's two-level HTML template layout.
- refactor: Separate the Lua filters by concern, `title-block.lua` for title-block metadata and `landscape-page-size.lua` for page geometry, each scoped to the `docx` format.
- feat: Initial release.
