--[[
  project-tags.lua — tag bibliography entries with the larger studies they
  came out of (HCP-D, TAG, ...), and emit the filter bar that
  project-filter.html wires up.

  Reads projects.json:

      {
        "projects": [ { "id": "TAG", "label": "TAG", "name": "...", "url": "..." }, ... ],
        "papers":   { "<citekey>": [ "TAG", ... ], ... }
      }

  `projects` is an array so the filter bar keeps the order written there.
  `url` is optional; every other field is required.

  Runs after citeproc and oa-links.lua (so the tags sit below the [PDF] link)
  and before group-years.lua, on the flat `#refs` Div.

  Unlike oa-links.lua, nothing here is optional. A missing or malformed file,
  an unknown project id, a citekey that matches no rendered entry, or a
  project with no papers is an error: each of those means the page would
  quietly show the wrong tags.
--]]

local PROJECTS_PATH = "projects.json"

local function fail(msg)
  error("project-tags.lua: " .. msg, 0)
end

local function load_projects()
  local fh = io.open(PROJECTS_PATH, "r")
  if not fh then fail(PROJECTS_PATH .. " not found (expected next to pubs.qmd)") end
  local raw = fh:read("a")
  fh:close()

  local ok, data = pcall(pandoc.json.decode, raw)
  if not ok or type(data) ~= "table" then fail("could not parse " .. PROJECTS_PATH) end
  if type(data.projects) ~= "table" or #data.projects == 0 then
    fail(PROJECTS_PATH .. ": `projects` must be a non-empty array")
  end
  if type(data.papers) ~= "table" then
    fail(PROJECTS_PATH .. ": `papers` must be an object of citekey -> [project ids]")
  end

  local order, by_id = {}, {}
  for i, p in ipairs(data.projects) do
    for _, field in ipairs({ "id", "label", "name" }) do
      if type(p[field]) ~= "string" or p[field] == "" then
        fail(string.format("projects[%d] is missing `%s`", i, field))
      end
    end
    if not p.id:match("^[%w_-]+$") then
      fail("project id '" .. p.id .. "' may only contain letters, digits, _ and -")
    end
    if by_id[p.id] then fail("project id '" .. p.id .. "' is defined twice") end
    if p.url ~= nil and (type(p.url) ~= "string" or not p.url:match("^https?://")) then
      fail("project '" .. p.id .. "' has a url that is not http(s)")
    end
    by_id[p.id] = p
    order[#order + 1] = p.id
  end

  local papers = {}
  for key, ids in pairs(data.papers) do
    if key:sub(1, 1) ~= "_" then
      if type(ids) ~= "table" or #ids == 0 then
        fail("papers['" .. key .. "'] must be a non-empty array of project ids")
      end
      local seen = {}
      for _, id in ipairs(ids) do
        if not by_id[id] then
          fail("papers['" .. key .. "'] uses undefined project id '" .. tostring(id) .. "'")
        end
        if seen[id] then fail("papers['" .. key .. "'] lists '" .. id .. "' twice") end
        seen[id] = true
      end
      papers[key] = ids
    end
  end

  return order, by_id, papers
end

local order, projects, papers = load_projects()

local function esc(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

local function chips(ids)
  local inlines = pandoc.List()
  for i, id in ipairs(ids) do
    if i > 1 then inlines:insert(pandoc.Space()) end
    local p = projects[id]
    inlines:insert(pandoc.Link(
      { pandoc.Str(p.label) },
      "#project-" .. id,
      p.name,
      pandoc.Attr("", { "pub-project" }, { ["data-project"] = id })
    ))
  end
  return pandoc.Div({ pandoc.Plain(inlines) }, pandoc.Attr("", { "pub-projects" }))
end

-- Hidden until project-filter.html runs, so readers without JS never see
-- buttons that do nothing.
local function filter_bar(counts)
  local parts = {
    '<nav id="pub-project-filter" class="pub-project-filter" aria-label="Filter by project" hidden>',
    '<span class="pub-project-filter-label">Filter by project:</span>',
    '<button type="button" class="pub-project-btn" data-project="" aria-pressed="true">All</button>',
  }
  for _, id in ipairs(order) do
    local p = projects[id]
    parts[#parts + 1] = string.format(
      '<button type="button" class="pub-project-btn" data-project="%s" data-name="%s" data-url="%s" title="%s" aria-pressed="false">%s <span class="pub-project-count">%d</span></button>',
      esc(id), esc(p.name), esc(p.url or ""), esc(p.name), esc(p.label), counts[id])
  end
  parts[#parts + 1] = '<p class="pub-project-status" aria-live="polite"></p>'
  parts[#parts + 1] = '</nav>'
  return pandoc.RawBlock("html", table.concat(parts, "\n"))
end

function Div(div)
  if div.identifier ~= "refs" then return nil end

  local counts, matched = {}, {}
  for _, id in ipairs(order) do counts[id] = 0 end
  local n_entries, n_tagged = 0, 0

  div.content = div.content:map(function(blk)
    if blk.t ~= "Div" or not blk.classes:includes("csl-entry") then return blk end
    n_entries = n_entries + 1
    local key = blk.identifier:match("^ref%-(.+)$")
    local ids = key and papers[key]
    if not ids then return blk end
    matched[key] = true
    n_tagged = n_tagged + 1
    for _, id in ipairs(ids) do counts[id] = counts[id] + 1 end
    blk.attributes["data-projects"] = table.concat(ids, " ")
    blk.content:insert(chips(ids))
    return blk
  end)

  local stray = {}
  for key in pairs(papers) do
    if not matched[key] then stray[#stray + 1] = key end
  end
  if #stray > 0 then
    table.sort(stray)
    fail("citekeys in " .. PROJECTS_PATH .. " match no bibliography entry: "
      .. table.concat(stray, ", "))
  end

  local empty = {}
  for _, id in ipairs(order) do
    if counts[id] == 0 then empty[#empty + 1] = id end
  end
  if #empty > 0 then
    fail("projects with no tagged papers (tag one or remove the project): "
      .. table.concat(empty, ", "))
  end

  local summary = {}
  for _, id in ipairs(order) do summary[#summary + 1] = id .. "=" .. counts[id] end
  io.stderr:write(string.format("project-tags.lua: %d/%d entries tagged (%s)\n",
    n_tagged, n_entries, table.concat(summary, ", ")))

  return { filter_bar(counts), div }
end
