local image_nvim = require("image")
local integrations = require("diagram/integrations")

---@class State
local state = {
  renderer_options = {
    mermaid = {
      background = nil,
      theme = nil,
      width = nil,
      height = nil,
    },
    plantuml = {
      charset = nil,
    },
    d2 = {
      theme_id = nil,
      dark_theme_id = nil,
      scale = nil,
      layout = nil,
      sketch = nil,
    },
  },
  integrations = {
    integrations.markdown,
    integrations.neorg,
  },
  diagrams = {},
}

local clear_buffer = function(bufnr)
  for _, diagram in ipairs(state.diagrams) do
    if diagram.bufnr == bufnr and diagram.image ~= nil then diagram.image:clear() end
  end
end

---@param bufnr number
---@param winnr number
---@param integration Integration
local render_buffer = function(bufnr, winnr, integration)
  clear_buffer(bufnr)
  local diagrams = integration.query_buffer_diagrams(bufnr)

  for _, diagram in ipairs(diagrams) do
    ---@type Renderer
    local renderer = nil
    for _, r in ipairs(integration.renderers) do
      if r.id == diagram.renderer_id then
        renderer = r
        break
      end
    end
    assert(renderer, "diagram: cannot find renderer with id `" .. diagram.renderer_id .. "`")

    local renderer_options = state.renderer_options[renderer.id] or {}
    local rendered_path = renderer.render(diagram.source, renderer_options)
    if not rendered_path then return end

    local diagram_col = diagram.range.start_col
    local diagram_row = diagram.range.start_row
    if vim.bo[bufnr].filetype == "norg" then
      diagram_row = diagram_row - 1
    end

    local image = image_nvim.from_file(rendered_path, {
      buffer = bufnr,
      window = winnr,
      with_virtual_padding = true,
      inline = true,
      x = diagram_col,
      y = diagram_row,
    })
    diagram.image = image
    table.insert(state.diagrams, diagram)
    image:render()
  end
end

---@param opts PluginOptions
local setup = function(opts)
  local ok = pcall(require, "image")
  if not ok then error("diagram: missing dependency `3rd/image.nvim`") end

  state.integrations = opts.integrations or state.integrations
  state.renderer_options = vim.tbl_deep_extend("force", state.renderer_options, opts.renderer_options or {})

  local current_bufnr = vim.api.nvim_get_current_buf()
  local current_winnr = vim.api.nvim_get_current_win()
  local current_ft = vim.bo[current_bufnr].filetype

  local setup_buffer = function(bufnr, integration)
    -- render
    vim.api.nvim_create_autocmd({ "InsertLeave", "BufWinEnter", "TextChanged" }, {
      buffer = bufnr,
      callback = function(buf_ev)
        local winnr = buf_ev.event == "BufWinEnter" and buf_ev.winnr or vim.api.nvim_get_current_win()
        render_buffer(bufnr, winnr, integration)
      end,
    })

    -- clear
    vim.api.nvim_create_autocmd("InsertEnter", {
      buffer = bufnr,
      callback = function()
        clear_buffer(bufnr)
      end,
    })
  end

  -- setup integrations
  for _, integration in ipairs(state.integrations) do
    vim.api.nvim_create_autocmd("FileType", {
      pattern = integration.filetypes,
      callback = function(ft_event)
        setup_buffer(ft_event.buf, integration)
      end,
    })

    -- first render
    if vim.tbl_contains(integration.filetypes, current_ft) then
      setup_buffer(current_bufnr, integration)
      render_buffer(current_bufnr, current_winnr, integration)
    end
  end
end

local get_cache_dir = function()
  return vim.fn.stdpath("cache") .. "/diagram-cache"
end

return {
  setup = setup,
  get_cache_dir = get_cache_dir,
}
