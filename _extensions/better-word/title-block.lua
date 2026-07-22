--- Better Word - Format Extension
--- @module "better-word"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Prepare title-block metadata the OpenXML template cannot build itself.
--- @description
--- Quarto denormalises author metadata into `by-author` / `by-affiliation`, but
--- regenerates them at template time (so filter edits to those keys are ignored)
--- and stores identifiers as inlines (which cannot sit inside a `<w:t>` or an
--- attribute value). This filter builds parallel `docx-by-author` /
--- `docx-by-affiliation` models, and a `docx-doi` value, whose numbers are
--- raw-OpenXML text and whose DOI / ORCID / email are field-code HYPERLINK
--- fields, so title-metadata.xml can render superscript affiliation numbers and
--- clickable identifiers without producing invalid XML.
--- Concern: title-block metadata only. Page geometry lives in landscape-page-size.lua.

--- Wrap raw OpenXML as inline metadata the template can emit verbatim.
--- Any ordinary metadata referenced with `$var$` is rendered by the docx writer
--- as its own `<w:r><w:t>` run; nesting that in a `<w:t>` or an attribute value
--- produces invalid XML that Word rejects. A raw-OpenXML inline is emitted as is,
--- so it can carry a superscript number or a complete field-code hyperlink.
--- @param xml string A fragment of well-formed OpenXML.
--- @return table inlines A `MetaInlines` holding a single raw-OpenXML inline.
local function raw_openxml(xml)
  return pandoc.MetaInlines({ pandoc.RawInline('openxml', xml) })
end

--- Escape a string for inclusion in XML text or an attribute value.
--- @param text string Raw text.
--- @return string escaped XML-safe text.
local function xml_escape(text)
  return (text:gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;'))
end

--- Build a clickable link as a field-code HYPERLINK, wrapped as raw-OpenXML
--- metadata. A `w:fldSimple` HYPERLINK field carries the target in its `w:instr`
--- attribute, so it needs no `word/document.xml.rels` entry (unlike a
--- `<w:hyperlink r:id>`, whose dangling relationship would trigger Word's repair
--- dialog). The display run uses the reference-doc's built-in `Hyperlink`
--- character style.
--- @param url string Link target (already a plain string).
--- @param text string Visible link text.
--- @return table inlines A `MetaInlines` holding the raw-OpenXML field.
local function hyperlink(url, text)
  local field = '<w:fldSimple w:instr=" HYPERLINK &quot;'
    .. xml_escape(url)
    .. '&quot; "><w:r><w:rPr><w:rStyle w:val="Hyperlink" /></w:rPr>'
    .. '<w:t xml:space="preserve">'
    .. xml_escape(text)
    .. '</w:t></w:r></w:fldSimple>'
  return raw_openxml(field)
end

--- Join an author's affiliation numbers into a comma-separated raw-OpenXML value.
--- @param affiliations table|nil The author's `affiliations` list.
--- @return table|nil numbers Raw-OpenXML affiliation numbers, or nil if none.
local function affiliation_numbers(affiliations)
  local numbers = {}
  if affiliations ~= nil then
    for index = 1, #affiliations do
      numbers[#numbers + 1] = pandoc.utils.stringify(affiliations[index].number)
    end
  end
  if #numbers == 0 then
    return nil
  end
  return raw_openxml(table.concat(numbers, ', '))
end

--- Build a clickable identifier link from an inline metadata value.
--- @param value any Raw metadata value (inlines), or nil.
--- @param prefix string URL prefix prepended to the stringified value.
--- @return table|nil link A raw-OpenXML HYPERLINK field, or nil when absent.
local function identifier_link(value, prefix)
  if value == nil then
    return nil
  end
  local text = pandoc.utils.stringify(value)
  return hyperlink(prefix .. text, text)
end

--- Build a parallel author/affiliation model for the template.
--- Names stay as inlines (rendered as their own runs); affiliation numbers are
--- flattened to raw-OpenXML text so the template can place them inside a
--- superscript `<w:t>`; email and ORCID become field-code HYPERLINK fields so
--- they render clickable.
--- @param meta table Pandoc metadata.
local function build_author_model(meta)
  local authors = meta['by-author']
  if authors ~= nil then
    local model = {}
    for index = 1, #authors do
      local author = authors[index]
      local corresponding = false
      if author.attributes ~= nil and author.attributes.corresponding ~= nil then
        corresponding = author.attributes.corresponding
      end
      model[index] = {
        name = author.name.literal,
        affiliations = affiliation_numbers(author.affiliations),
        corresponding = corresponding,
        email = identifier_link(author.email, 'mailto:'),
        orcid = identifier_link(author.orcid, 'https://orcid.org/'),
      }
    end
    meta['docx-by-author'] = model
  end

  local affiliations = meta['by-affiliation']
  if affiliations ~= nil then
    local model = {}
    for index = 1, #affiliations do
      local affiliation = affiliations[index]
      model[index] = {
        number = raw_openxml(pandoc.utils.stringify(affiliation.number)),
        name = affiliation.name,
        department = affiliation.department,
        city = affiliation.city,
        country = affiliation.country,
      }
    end
    meta['docx-by-affiliation'] = model
  end
end

--- First pass: build the author/affiliation model and the clickable DOI.
--- @param meta table Pandoc metadata.
--- @return table meta Metadata with `docx-by-author`, `docx-by-affiliation`, and
--- `docx-doi` set as needed.
local function build_title_block(meta)
  build_author_model(meta)
  meta['docx-doi'] = identifier_link(meta['doi'], 'https://doi.org/')
  return meta
end

if not quarto.doc.is_format('docx') then
  return {}
end

return {
  { Meta = build_title_block },
}
