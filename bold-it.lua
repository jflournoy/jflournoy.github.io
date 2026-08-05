--[[
  bold-it.lua — bold "Flournoy, J. C." wherever it appears in a CSL bibliography.

  Operates on citeproc *output*, so it must run after citeproc (see the
  `filters:` key in pubs.qmd). Rendered APA output tokenizes the name as
  separate Str elements with punctuation attached, e.g.

      Str"Flournoy," Space Str"J." Space Str"C.,"

  Observed variants in this bibliography: "J. C.," (mid-list), "J. C." (final
  author), and "J.," / "J." (entries whose bib record omits the middle
  initial). Match the surname, then greedily consume following single-initial
  tokens, stopping before anything that is not an initial — a co-author
  surname, "&", or the "(2019)." that follows a sole-authored entry.
--]]

-- A single initial: "J." or "C.", optionally with the author-separating
-- comma attached. Deliberately does NOT match "(2019)." or "Mills,".
local function initial_parts(text)
  local letter, punct = text:match("^([A-Z]%.)(,?)$")
  return letter, punct
end

local function bold_name_in(inlines)
  local k = 1
  while k <= #inlines do
    local el = inlines[k]
    if el.t == "Str" and (el.text == "Flournoy," or el.text == "Flournoy") then
      local pieces = { "Flournoy," }
      local consumed = 0 -- inlines after k that belong to the name
      local trailing = "" -- separator comma, kept outside the bold run
      local j = k + 1
      while j + 1 <= #inlines
        and inlines[j].t == "Space"
        and inlines[j + 1].t == "Str" do
        local letter, punct = initial_parts(inlines[j + 1].text)
        if not letter then break end
        pieces[#pieces + 1] = letter
        trailing = punct
        consumed = j + 1 - k
        j = j + 2
      end

      -- Only bold when at least one initial followed; a bare "Flournoy" is
      -- more likely part of a title or a different person.
      if consumed > 0 then
        for _ = 1, consumed do
          table.remove(inlines, k + 1)
        end
        inlines[k] = pandoc.Strong { pandoc.Str(table.concat(pieces, " ")) }
        if trailing ~= "" then
          table.insert(inlines, k + 1, pandoc.Str(trailing))
          k = k + 1
        end
      end
    end
    k = k + 1
  end
  return inlines
end

local highlight_author_filter = {
  Para = function(el)
    el.content = bold_name_in(el.content)
    return el
  end,
  Plain = function(el)
    el.content = bold_name_in(el.content)
    return el
  end,
}

function Div(div)
  if div.identifier:find("^ref%-") then
    return pandoc.walk_block(div, highlight_author_filter)
  end
  return nil
end
