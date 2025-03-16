local renderers = require("diagram/renderers")
local ts_query = require("vim.treesitter.query")

---@type vim.treesitter.Query
local query = nil

---@class Integration
local M = {
  id = "markdown",
  filetypes = { "markdown" },
  renderers = {
    renderers.mermaid,
    renderers.plantuml,
    renderers.d2,
    renderers.gnuplot,
  },
}

M.query_buffer_diagrams = function(bufnr)
  if not query then
    query = ts_query.parse("markdown", "(fenced_code_block (info_string) @info (code_fence_content) @code)")
  end

  local buf = bufnr or vim.api.nvim_get_current_buf()
  local parser = vim.treesitter.get_parser(buf, "markdown")
  parser:parse(true)

  local root = parser:parse()[1]:root()
  local matches = query:iter_captures(root, bufnr)

  ---@type Diagram[]
  local diagrams = {}
  local current_language = nil
  ---@type { start_row: number, start_col: number, end_row: number, end_col: number }
  local current_range = nil
  for id, node in matches do
    local key = query.captures[id]
    local value = vim.treesitter.get_node_text(node, bufnr)
    if node:parent():parent() and node:parent():parent():type() == "block_quote" then
      value = value:gsub("\n>", "\n"):gsub("^>", "")
    end

    if key == "info" then
      ---@diagnostic disable-next-line: unused-local
      local start_row, _start_col, end_row, end_col = node:range()
      current_range = {
        start_row = start_row,
        start_col = 0,
        end_row = end_row,
        end_col = end_col,
      }
      current_language = value
    else
      if
        current_language == "mermaid"
        or current_language == "plantuml"
        or current_language == "d2"
        or current_language == "gnuplot"
      then
        table.insert(diagrams, {
          bufnr = bufnr,
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
