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
      current_language = value
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
        })
      end
    end
  end

  return diagrams
end

return M
