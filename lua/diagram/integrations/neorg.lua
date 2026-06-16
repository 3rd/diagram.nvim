local renderers = require("diagram/renderers")
local ts_query = require("vim.treesitter.query")

---@type vim.treesitter.Query
local query = nil

---@class Integration
local M = {
  id = "neorg",
  filetypes = { "norg" },
  renderers = {
    renderers.mermaid,
    renderers.plantuml,
    renderers.d2,
    renderers.gnuplot,
  },
}

--- Parse tag_params to extract language and JSON options
--- Supports: @code mermaid {"scale": 2, "theme": "dark"}
---@param tag_params string
---@return string language, table|nil options
local parse_tag_params = function(tag_params)
  -- Extract language name (first word)
  local lang = tag_params:match("^(%S+)")
  if not lang then return "", nil end

  -- Extract options (everything after first word)
  local options_str = tag_params:match("^%S+%s+(.+)")
  if not options_str then return lang, nil end

  -- Trim whitespace
  options_str = options_str:match("^%s*(.-)%s*$")

  -- Try parsing as JSON
  local ok, result = pcall(vim.fn.json_decode, options_str)
  if ok and type(result) == "table" then return lang, result end

  -- If JSON parsing fails, return just the language
  return lang, nil
end

M.query_buffer_diagrams = function(bufnr)
  if not query then
    query = ts_query.parse(
      "norg",
      [[
      (ranged_verbatim_tag
        name: (tag_name) @tag_name
        (tag_parameters)? @tag_params
        content: (ranged_verbatim_tag_content) @content
      )
      ]]
    )
  end

  local buf = bufnr or vim.api.nvim_get_current_buf()
  local parser = vim.treesitter.get_parser(buf, "norg")
  parser:parse(true)

  local root = parser:parse()[1]:root()
  local matches = query:iter_captures(root, buf)

  ---@type Diagram[]
  local diagrams = {}
  local current_language = nil
  local current_options = nil
  ---@type { start_row: number, start_col: number, end_row: number, end_col: number }
  local current_range = nil

  for id, node in matches do
    local key = query.captures[id]
    local value = vim.treesitter.get_node_text(node, buf)

    if key == "tag_name" then
      local start_row, start_col, _, _ = node:range()
      current_range = {
        start_row = start_row,
        start_col = start_col,
        end_row = 0,
        end_col = 0,
      }
    elseif key == "tag_params" then
      current_language, current_options = parse_tag_params(value)
    elseif key == "content" then
      if
        current_language == "mermaid"
        or current_language == "plantuml"
        or current_language == "d2"
        or current_language == "gnuplot"
      then
        local _, _, end_row, end_col = node:range()
        current_range.end_row = end_row
        current_range.end_col = end_col
        table.insert(diagrams, {
          bufnr = buf,
          renderer_id = current_language,
          source = value,
          range = current_range,
          options = current_options,
        })
      end
    end
  end

  return diagrams
end

return M
