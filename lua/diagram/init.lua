local image_nvim = require("image")
local integrations = require("diagram/integrations")

---@class State
local state = {
  renderer_options = {
    mermaid = {
      background = nil,
      theme = nil,
    },
    plantuml = {
      charset = nil,
    },
  },
  integrations = {
    integrations.markdown,
    integrations.neorg,
  },
  diagrams = {},
  rendering_disabled_buffers = {},
  globally_disabled = false,
}

local clear_buffer = function(bufnr)
  for _, diagram in ipairs(state.diagrams) do
    if diagram.bufnr == bufnr and diagram.image ~= nil then diagram.image:clear() end
  end
end

---@param bufnr? number
local should_render = function(bufnr)
  if bufnr == nil then return not state.globally_disabled end
  return not state.globally_disabled and not state.rendering_disabled_buffers[bufnr]
end

---@param bufnr number
---@param winnr number
---@param integration Integration
local render_buffer = function(bufnr, winnr, integration)
  if not should_render(bufnr) then return end
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

    local image = image_nvim.from_file(rendered_path, {
      buffer = bufnr,
      window = winnr,
      with_virtual_padding = true,
      inline = true,
      x = diagram.range.start_col,
      y = diagram.range.start_row,
    })
    diagram.image = image
    table.insert(state.diagrams, diagram)
    image:render()
  end
end

local toggle_rendering = function(action, opts)
  opts = opts or {}
  local bufnr = opts.buffer

  if bufnr then
    if action == "toggle" then
      state.rendering_disabled_buffers[bufnr] = not state.rendering_disabled_buffers[bufnr]
    elseif action == "enable" then
      state.rendering_disabled_buffers[bufnr] = false
    elseif action == "disable" then
      state.rendering_disabled_buffers[bufnr] = true
    else
      return
    end
  else
    if action == "toggle" then
      state.globally_disabled = not state.globally_disabled
    elseif action == "enable" then
      state.globally_disabled = false
    elseif action == "disable" then
      state.globally_disabled = true
    else
      return
    end
  end

  if bufnr then
    if not state.rendering_disabled_buffers[bufnr] then
      for _, integration in ipairs(state.integrations) do
        if vim.tbl_contains(integration.filetypes, vim.bo[bufnr].filetype) then
          render_buffer(bufnr, vim.api.nvim_get_current_win(), integration)
        end
      end
    else
      clear_buffer(bufnr)
    end
  else
    if not state.globally_disabled then
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        for _, integration in ipairs(state.integrations) do
          if vim.tbl_contains(integration.filetypes, vim.bo[buf].filetype) then
            render_buffer(buf, vim.api.nvim_get_current_win(), integration)
          end
        end
      end
    else
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        clear_buffer(buf)
      end
    end
  end
end

local enable = function(opts)
  toggle_rendering("enable", opts)
end

local disable = function(opts)
  toggle_rendering("disable", opts)
end

local toggle = function(opts)
  toggle_rendering("toggle", opts)
end

local is_enabled = function(opts)
  opts = opts or {}
  local bufnr = opts.buffer or vim.api.nvim_get_current_buf()
  return not state.globally_disabled and not state.rendering_disabled_buffers[bufnr]
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

  vim.api.nvim_create_user_command("Diagram", function(cmd_opts)
    local action = cmd_opts.args
    toggle_rendering(action)
  end, {
    nargs = 1,
    complete = function(_, _, _)
      return { "toggle", "enable", "disable" }
    end,
  })

  vim.api.nvim_create_user_command("DiagramBuf", function(cmd_opts)
    local action = cmd_opts.args
    local bufnr = vim.api.nvim_get_current_buf()
    toggle_rendering(action, { buffer = bufnr })
  end, {
    nargs = 1,
    complete = function(_, _, _)
      return { "toggle", "enable", "disable" }
    end,
  })
end

return {
  setup = setup,
  enable = enable,
  disable = disable,
  toggle = toggle,
  is_enabled = is_enabled,
}
