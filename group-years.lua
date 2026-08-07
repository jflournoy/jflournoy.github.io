--[[
  group-years.lua — split the CSL bibliography into year sections.

  Runs after citeproc, on the `#refs` Div that Quarto/citeproc emits:

      <div id="refs" class="references csl-bib-body">
        <div id="ref-key" class="csl-entry">...</div>
        ...
      </div>

  Entries arrive already sorted newest-first (apa-cv.csl sorts by descending
  date), so we only need to detect year boundaries, not re-sort. The year is
  read from citeproc's rendered "(2024)." rather than from the citekey —
  citekeys disagree with the bib `date` field in several entries here (e.g.
  bryceBrainParcellationSelection2021a).

  Every entry is emitted exactly once: entries whose year cannot be parsed are
  collected into a trailing "Other" section rather than dropped.
--]]

local YEAR_HEADING_LEVEL = 2

-- Pull the first 4-digit year out of a rendered entry. APA prints it
-- parenthesized right after the author list: "... (2024). Title..." — prefer
-- that form, and fall back to any bare 4-digit run (e.g. "(2021, September)"
-- or "(in press)" entries that still carry a year elsewhere).
local function entry_year(block)
  local text = pandoc.utils.stringify(block)
  local year = text:match("%((%d%d%d%d)%)")
    or text:match("%((%d%d%d%d),")
    or text:match("%((%d%d%d%d)%a")
  if year then return year end
  -- Last resort: first plausible year anywhere in the entry.
  return text:match("[^%d](19%d%d)[^%d]") or text:match("[^%d](20%d%d)[^%d]")
end

function Div(div)
  if div.identifier ~= "refs" then return nil end

  local out = pandoc.List()
  local current_year = nil
  local unknown = pandoc.List()
  local n_in, n_out = 0, 0

  -- Buffer the entries of one year inside their own bib-body div so the
  -- hanging-indent CSS keeps applying.
  local bucket = nil
  local function flush()
    if bucket and #bucket > 0 then
      out:insert(pandoc.Div(bucket, pandoc.Attr("", { "csl-bib-body", "hanging-indent" })))
    end
    bucket = nil
  end

  for _, block in ipairs(div.content) do
    local is_entry = block.t == "Div"
      and block.classes
      and block.classes:includes("csl-entry")

    if is_entry then
      n_in = n_in + 1
      local year = entry_year(block)
      if year then
        if year ~= current_year then
          flush()
          current_year = year
          out:insert(pandoc.Header(
            YEAR_HEADING_LEVEL,
            { pandoc.Str(year) },
            pandoc.Attr("year-" .. year, { "pub-year" })
          ))
          bucket = pandoc.List()
        end
        bucket:insert(block)
        n_out = n_out + 1
      else
        unknown:insert(block)
      end
    else
      -- Preserve any non-entry content. citeproc emits none today, but do not
      -- silently discard it if that changes.
      flush()
      out:insert(block)
    end
  end
  flush()

  if #unknown > 0 then
    out:insert(pandoc.Header(
      YEAR_HEADING_LEVEL,
      { pandoc.Str("Other") },
      pandoc.Attr("year-other", { "pub-year" })
    ))
    out:insert(pandoc.Div(unknown, pandoc.Attr("", { "csl-bib-body", "hanging-indent" })))
    n_out = n_out + #unknown
  end

  -- Loud failure beats a page that quietly lost references.
  if n_in ~= n_out then
    error(string.format(
      "group-years.lua: %d entries in, %d out — entries would be lost", n_in, n_out))
  end

  return pandoc.Div(out, div.attr)
end
