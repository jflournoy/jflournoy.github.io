--[[
  oa-links.lua — append an open-access full-text link to each bibliography
  entry, and tag the journal name for styling.

  Reads oa-links.json (built by fetch-oa-links.py). Runs after citeproc and
  before group-years.lua, so it sees citeproc's own output shape: a `#refs`
  Div of `csl-entry` Divs whose identifiers are "ref-<citekey>".

  Link wording is deliberately cautious. Unpaywall reports a direct PDF for
  only ~a third of this bibliography; the rest resolve to an OA landing page.
  Labelling those "PDF" would promise a file and deliver an abstract, so only
  genuine `url_for_pdf` hits get the PDF label.
--]]

local json_path = "oa-links.json"

local function read_links()
  local fh = io.open(json_path, "r")
  if not fh then
    io.stderr:write("oa-links.lua: " .. json_path .. " not found; no links added\n")
    return {}
  end
  local raw = fh:read("a")
  fh:close()
  local ok, decoded = pcall(pandoc.json.decode, raw)
  if not ok or type(decoded) ~= "table" then
    io.stderr:write("oa-links.lua: could not parse " .. json_path .. "\n")
    return {}
  end
  return decoded
end

local links = read_links()

-- Journal names, read from the bibliography itself. APA italicises the
-- container title -- but on entries with no container (a thesis, a preprint
-- comment) it italicises the *title* instead, so "first Emph" would wrongly
-- tag those. Match against the known container title instead.
local containers = {}
do
  local proc = io.popen("pandoc -f biblatex -t csljson Flournoy.bib 2>/dev/null")
  if proc then
    local raw = proc:read("a")
    proc:close()
    local ok, entries = pcall(pandoc.json.decode, raw)
    if ok and type(entries) == "table" then
      for _, e in pairs(entries) do
        if e.id and e["container-title"] then
          containers[e.id] = pandoc.text.lower(e["container-title"])
        end
      end
    end
  end
end

local function tag_journal(blk, key)
  local want = containers[key]
  if not want then return blk end
  local tagged = false
  return pandoc.walk_block(blk, {
    Emph = function(em)
      if tagged then return nil end
      if pandoc.text.lower(pandoc.utils.stringify(em)) ~= want then return nil end
      tagged = true
      return pandoc.Span(em.content, pandoc.Attr("", { "pub-journal" }))
    end,
  })
end

local n_entries, n_linked, n_pdf, n_journal = 0, 0, 0, 0

local function decorate(div)
  local key = div.identifier:match("^ref%-(.+)$")
  if not key then return nil end
  n_entries = n_entries + 1

  div.content = div.content:map(function(b) return tag_journal(b, key) end)
  if containers[key] then n_journal = n_journal + 1 end

  local link = links[key]
  if not link or not link.url then return div end
  n_linked = n_linked + 1
  local is_pdf = link.kind == "pdf"
  if is_pdf then n_pdf = n_pdf + 1 end

  local label = is_pdf and "PDF" or "Free full text"
  local anchor = pandoc.Link(
    { pandoc.Str(label) },
    link.url,
    "",
    pandoc.Attr("", { "pub-oa", is_pdf and "pub-oa-pdf" or "pub-oa-html" })
  )

  -- Append to the entry's last block so the badge sits inline at the end of
  -- the reference rather than forming its own paragraph.
  local last = div.content[#div.content]
  if last and last.content then
    last.content:insert(pandoc.Space())
    last.content:insert(anchor)
  else
    div.content:insert(pandoc.Plain { anchor })
  end
  return div
end

function Div(div)
  if div.identifier ~= "refs" then return nil end

  div.content = div.content:map(function(blk)
    if blk.t == "Div" and blk.classes:includes("csl-entry") then
      return decorate(blk) or blk
    end
    return blk
  end)

  -- Coverage is visible in the render log: a falling count means the cache
  -- has gone stale relative to the bibliography.
  io.stderr:write(string.format(
    "oa-links.lua: %d/%d entries linked (%d direct PDF, %d landing page); "
      .. "%d journal names tagged\n",
    n_linked, n_entries, n_pdf, n_linked - n_pdf, n_journal))

  return div
end
