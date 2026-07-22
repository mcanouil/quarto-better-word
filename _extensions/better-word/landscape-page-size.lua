--- Better Word - Format Extension
--- @module "better-word"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Share one page geometry between the base section and .landscape sections.
--- @description
--- Builds the base section properties (`w:sectPr`) from the shared `docx-page-*`
--- metadata and exposes them to the template as the `docx-sectpr` variable, then
--- rewrites every `.landscape` div to use the same geometry. Quarto's built-in
--- landscape filter (quarto-post/landscape.lua) inserts an empty
--- `<w:sectPr></w:sectPr>` before the content (which strips the preceding
--- section's page size and margins) and a landscape `<w:sectPr>` after it with
--- hardcoded A4 dimensions. This filter removes those and inserts breaks derived
--- from the shared geometry, so the base and landscape sections stay in sync.
--- Concern: page geometry only. Title-block metadata lives in title-block.lua.

--- Default A4 portrait geometry, in twips (1/1440 inch).
local DEFAULT_PAGE_WIDTH = 11906
local DEFAULT_PAGE_HEIGHT = 16838
local DEFAULT_PAGE_MARGIN = 1440

--- Resolved page geometry, populated from metadata in the first pass.
local page_width = DEFAULT_PAGE_WIDTH
local page_height = DEFAULT_PAGE_HEIGHT
local page_margin = DEFAULT_PAGE_MARGIN

--- Read a metadata value as a positive integer, or fall back to a default.
--- @param value any Raw metadata value (MetaString, MetaInlines, or nil).
--- @param default integer Fallback when the value is missing or not a number.
--- @return integer twips Resolved measurement in twips.
local function meta_to_twips(value, default)
  if value == nil then
    return default
  end
  local number = tonumber(pandoc.utils.stringify(value))
  if number == nil or number <= 0 then
    return default
  end
  return math.floor(number)
end

--- Build the `w:pgMar` element shared by both orientations.
--- @return string margin OpenXML `w:pgMar` element.
local function page_margin_xml()
  return string.format(
    '<w:pgMar w:top="%d" w:right="%d" w:bottom="%d" w:left="%d" w:header="708" w:footer="708" w:gutter="0" />',
    page_margin, page_margin, page_margin, page_margin
  )
end

--- Wrap section properties in the empty paragraph the landscape filter uses.
--- @param sect_pr string OpenXML `w:sectPr` element.
--- @return string paragraph OpenXML `w:p` carrying the section break.
local function section_paragraph(sect_pr)
  return '<w:p><w:pPr>' .. sect_pr .. '</w:pPr></w:p>'
end

--- Portrait base section properties, matching the document's base page.
--- @return string sect_pr OpenXML `w:sectPr` element.
local function base_sectpr_xml()
  return string.format(
    '<w:sectPr><w:pgSz w:w="%d" w:h="%d" />%s</w:sectPr>',
    page_width, page_height, page_margin_xml()
  )
end

--- Landscape section properties, base geometry with width and height swapped.
--- @return string sect_pr OpenXML `w:sectPr` element.
local function landscape_sectpr_xml()
  return string.format(
    '<w:sectPr><w:pgSz w:w="%d" w:h="%d" w:orient="landscape" />%s</w:sectPr>',
    page_height, page_width, page_margin_xml()
  )
end

--- First pass: resolve the shared page geometry and expose the base section.
--- The base `w:sectPr` is passed to the template as a raw-OpenXML metadata
--- variable (`docx-sectpr`) because numeric metadata is rendered as runs and
--- cannot be interpolated into attribute values directly.
--- @param meta table Pandoc metadata.
--- @return table meta Metadata with `docx-sectpr` set.
local function read_geometry(meta)
  page_width = meta_to_twips(meta['docx-page-width'], DEFAULT_PAGE_WIDTH)
  page_height = meta_to_twips(meta['docx-page-height'], DEFAULT_PAGE_HEIGHT)
  page_margin = meta_to_twips(meta['docx-page-margin'], DEFAULT_PAGE_MARGIN)
  meta['docx-sectpr'] = pandoc.MetaInlines({ pandoc.RawInline('openxml', base_sectpr_xml()) })
  return meta
end

--- Whether a block is an OpenXML section-break paragraph (`w:sectPr`).
--- @param block table A Pandoc block.
--- @return boolean is_break True for a raw-OpenXML block containing a `w:sectPr`.
local function is_section_break(block)
  return block.t == 'RawBlock'
    and block.format == 'openxml'
    and block.text:find('<w:sectPr') ~= nil
end

--- Wrap `.landscape` divs in shared-geometry section breaks, order-independently.
--- Quarto's built-in landscape filter inserts an empty portrait break (which drops
--- the preceding page size) and a hardcoded A4 landscape break. This handler works
--- whether it runs before or after that filter: it removes any section breaks
--- already inside the div, inserts breaks derived from the shared geometry, and
--- strips the `landscape` class so the built-in filter skips the div if it runs
--- afterwards.
--- @param div table Pandoc Div element.
--- @return table|nil div The wrapped Div, or nil to leave it unchanged.
local function fix_landscape(div)
  if not div.classes:includes('landscape') then
    return nil
  end
  div.classes = div.classes:filter(function(class) return class ~= 'landscape' end)
  local content = {}
  for _, block in ipairs(div.content) do
    if not is_section_break(block) then
      content[#content + 1] = block
    end
  end
  div.content = pandoc.Blocks(content)
  div.content:insert(1, pandoc.RawBlock('openxml', section_paragraph(base_sectpr_xml())))
  div.content:insert(pandoc.RawBlock('openxml', section_paragraph(landscape_sectpr_xml())))
  return div
end

if not quarto.doc.is_format('docx') then
  return {}
end

return {
  { Meta = read_geometry },
  { Div = fix_landscape },
}
