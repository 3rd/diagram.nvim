local renderers = require("diagram/renderers")
local ts_query = require("vim.treesitter.query")

---@type vim.treesitter.Query
local query = nil

---@class Integration
local M = {
  id = "vimwiki",
  filetypes = { "vimwiki" },
  renderers = {
    renderers.mermaid,
    renderers.plantuml,
    renderers.d2,
    renderers.gnuplot,
  },
}

-- Parse vimwiki native {{{ }}} code blocks
local function parse_vimwiki_blocks(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local diagrams = {}

  local i = 1
  while i <= #lines do
    local line = lines[i]
    -- Match {{{language at start of line (with optional whitespace)
    local language = line:match("^%s*{{{(%w+)%s*$")

    if language and (language == "mermaid" or language == "plantuml" or language == "d2" or language == "gnuplot") then
      local start_row = i - 1 -- 0-indexed
      local content_lines = {}
      local j = i + 1

      -- Find closing }}}
      while j <= #lines do
        local content_line = lines[j]
        if content_line:match("^%s*}}}%s*$") then
          -- Found closing tag
          local end_row = j - 1 -- 0-indexed
          local source = table.concat(content_lines, "\n")

          table.insert(diagrams, {
            bufnr = bufnr,
            renderer_id = language,
            source = source,
            range = {
              start_row = start_row,
              start_col = 0,
              end_row = end_row,
              end_col = 0,
            },
          })

          i = j -- Continue from after the closing tag
          break
        else
          table.insert(content_lines, content_line)
          j = j + 1
        end
      end

      if j > #lines then
        -- No closing tag found, skip this block
        i = i + 1
      end
    else
      i = i + 1
    end
  end

  return diagrams
end

-- Parse markdown-style fenced code blocks using treesitter
local function parse_markdown_blocks(bufnr)
  if not query then
    query = ts_query.parse("markdown", "(fenced_code_block (info_string) @info (code_fence_content) @code)")
  end

  local parser = vim.treesitter.get_parser(bufnr, "markdown")
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

M.query_buffer_diagrams = function(bufnr)
  local buf = bufnr or vim.api.nvim_get_current_buf()

  -- Parse both vimwiki native blocks and markdown fenced blocks
  local vimwiki_diagrams = parse_vimwiki_blocks(buf)
  local markdown_diagrams = parse_markdown_blocks(buf)

  -- Combine both results
  local all_diagrams = {}
  for _, diagram in ipairs(vimwiki_diagrams) do
    table.insert(all_diagrams, diagram)
  end
  for _, diagram in ipairs(markdown_diagrams) do
    table.insert(all_diagrams, diagram)
  end

  return all_diagrams
end

return M
