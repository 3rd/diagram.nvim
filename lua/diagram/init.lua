local hover = require("diagram/hover")
local image_nvim = require("image")
local integrations = require("diagram/integrations")
local RenderController = require("diagram/render")

---@class State
local state = {
  events = {
    render_buffer = { "InsertLeave", "BufWinEnter", "TextChanged" },
    clear_buffer = { "BufLeave" },
  },
  renderer_options = {
    mermaid = {
      background = nil,
      theme = nil,
      scale = nil,
      width = nil,
      height = nil,
      cli_args = nil,
    },
    plantuml = {
      charset = nil,
      cli_args = nil,
    },
    d2 = {
      theme_id = nil,
      dark_theme_id = nil,
      scale = nil,
      layout = nil,
      sketch = nil,
      cli_args = nil,
    },
    gnuplot = {
      size = nil,
      font = nil,
      theme = nil,
      cli_args = nil,
    },
  },
  integrations = {
    integrations.markdown,
    integrations.neorg,
  },
}

local controller = RenderController.new(image_nvim)

---@param bufnr number
---@param winnr number
---@param integration Integration
local render_buffer = function(bufnr, winnr, integration)
  controller:queue(bufnr, winnr, integration, state.renderer_options)
end

---@param opts PluginOptions
local setup = function(opts)
  local ok = pcall(require, "image")
  if not ok then 
    vim.notify("Missing dependency: 3rd/image.nvim\nPlease install image.nvim to use diagram.nvim", vim.log.levels.ERROR, { title = "Diagram.nvim" })
    return
  end

  state.integrations = opts.integrations or state.integrations
  if opts.events then
    for k, v in pairs(opts.events) do
      state.events[k] = v
    end
  end
  state.renderer_options = vim.tbl_deep_extend("force", state.renderer_options, opts.renderer_options or {})

  local current_bufnr = vim.api.nvim_get_current_buf()
  local current_winnr = vim.api.nvim_get_current_win()
  local current_ft = vim.bo[current_bufnr].filetype

  local setup_buffer = function(bufnr, integration)
    -- render (only if events are configured)
    if not state.events.render_buffer or #state.events.render_buffer == 0 then return end

    vim.api.nvim_create_autocmd(state.events.render_buffer, {
      buffer = bufnr,
      callback = function(buf_ev)
        local winnr = buf_ev.event == "BufWinEnter" and buf_ev.winnr or vim.api.nvim_get_current_win()
        render_buffer(bufnr, winnr, integration)
      end,
    })

    -- clear
    if state.events.clear_buffer and #state.events.clear_buffer > 0 then
      vim.api.nvim_create_autocmd(state.events.clear_buffer, {
        buffer = bufnr,
        callback = function()
          controller:clear_buffer(bufnr)
        end,
      })
    end
  end

  -- setup integrations
  for _, integration in ipairs(state.integrations) do
    vim.api.nvim_create_autocmd("FileType", {
      pattern = integration.filetypes,
      callback = function(ft_event)
        setup_buffer(ft_event.buf, integration)
      end,
    })

    -- first render (only if render events are enabled)
    if
      vim.tbl_contains(integration.filetypes, current_ft)
      and state.events.render_buffer
      and #state.events.render_buffer > 0
    then
      setup_buffer(current_bufnr, integration)
      render_buffer(current_bufnr, current_winnr, integration)
    elseif vim.tbl_contains(integration.filetypes, current_ft) then
      -- Still setup buffer for potential hover usage but don't auto-render
      setup_buffer(current_bufnr, integration)
    end
  end
end

local get_cache_dir = function()
  return vim.fn.stdpath("cache") .. "/diagram-cache"
end

local show_diagram_hover = function()
  hover.hover_at_cursor(state.integrations, state.renderer_options)
end

local render = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local winnr = vim.api.nvim_get_current_win()
  local ft = vim.bo[bufnr].filetype
  for _, integration in ipairs(state.integrations) do
    if vim.tbl_contains(integration.filetypes, ft) then
      render_buffer(bufnr, winnr, integration)
      return
    end
  end
end

local clear = function()
  controller:clear_buffer(vim.api.nvim_get_current_buf())
end

return {
  setup = setup,
  get_cache_dir = get_cache_dir,
  show_diagram_hover = show_diagram_hover,
  render = render,
  clear = clear,
}
