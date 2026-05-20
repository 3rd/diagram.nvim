local renderers = require("diagram/renderers")
local ts_query = require("vim.treesitter.query")

---@type vim.treesitter.Query
local query = nil

local supported_renderers = {
  mermaid = true,
  plantuml = true,
  d2 = true,
  gnuplot = true,
}

local function get_renderer_id(value)
  if not value then return nil end

  for token in value:gmatch("[^,%s]+") do
    if supported_renderers[token] then return token end
  end

  return nil
end

---@class Integration
local M = {
  id = "asciidoc",
  filetypes = { "asciidoc", "adoc" },
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
      "asciidoc",
      [[
      (section_block
        (element_attr
          (element_attr_marker)
          (attr_value) @attr
          (element_attr_marker))
        (listing_block
          (listing_block_start_marker) @start
          (listing_block_body) @code
          (listing_block_end_marker) @end)) @diagram

      (section_block
        (element_attr
          (element_attr_marker)
          (attr_value) @attr
          (element_attr_marker))
        (literal_block
          (literal_block_marker) @start
          (literal_block_body) @code
          (literal_block_marker) @end)) @diagram
      ]]
    )
  end

  local buf = bufnr or vim.api.nvim_get_current_buf()
  local parser = vim.treesitter.get_parser(buf, "asciidoc")
  local root = parser:parse(true)[1]:root()

  ---@type Diagram[]
  local diagrams = {}

  for _, match in query:iter_matches(root, buf) do
    local attr = match[1] and match[1][1]
    local start_marker = match[2] and match[2][1]
    local code = match[3] and match[3][1]
    local end_marker = match[4] and match[4][1]

    if attr and start_marker and code and end_marker then
      local renderer_id = get_renderer_id(vim.treesitter.get_node_text(attr, buf))
      if renderer_id then
        local start_row, start_col, _, _ = start_marker:range()
        local _, _, end_row, end_col = end_marker:range()
        table.insert(diagrams, {
          bufnr = buf,
          renderer_id = renderer_id,
          source = vim.treesitter.get_node_text(code, buf),
          range = {
            start_row = start_row,
            start_col = start_col,
            end_row = end_row,
            end_col = end_col,
          },
        })
      end
    end
  end

  return diagrams
end

return M
