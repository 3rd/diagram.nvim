local image_nvim = require("image")
local integrations = require("diagram/integrations")

---@class State
local state = {
  integrations = {
    integrations.markdown,
  },
  diagrams = {},
}

local clear_buffer = function(bufnr, winnr)
  local images = image_nvim.get_images({ buffer = bufnr, window = winnr })
  for _, image in ipairs(images) do
    image:clear()
  end
end

---@param bufnr number
---@param winnr number
---@param integration Integration
local render_buffer = function(bufnr, winnr, integration)
  clear_buffer(bufnr, winnr)
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

    local rendered_path = renderer.render(diagram.source)
    local image = image_nvim.from_file(rendered_path, {
      buffer = bufnr,
      window = winnr,
      with_virtual_padding = true,
      inline = true,
      x = diagram.range.start_col,
      y = diagram.range.start_row,
    })
    diagram.image = image
    image:render()
  end
end

---@param opts PluginOptions
local setup = function(opts)
  local ok = pcall(require, "image")
  if not ok then error("diagram: missing dependency `3rd/image.nvim`") end

  state.integrations = opts.integrations or state.integrations

  for _, integration in ipairs(state.integrations) do
    for _, ft in ipairs(integration.filetypes) do
      vim.api.nvim_create_autocmd("FileType", {
        pattern = ft,
        callback = function(ft_event)
          local ft_bufnr = ft_event.buf

          -- render
          vim.api.nvim_create_autocmd({ "InsertLeave", "BufWinEnter", "TextChanged" }, {
            buffer = ft_bufnr,
            callback = function(buf_ev)
              local bufnr = buf_ev.buf
              local winnr = buf_ev.event == "BufWinEnter" and buf_ev.winnr or vim.api.nvim_get_current_win()
              render_buffer(bufnr, winnr, integration)
            end,
          })

          -- clear
          vim.api.nvim_create_autocmd("InsertEnter", {
            buffer = ft_bufnr,
            callback = function(buf_ev)
              local bufnr = buf_ev.buf
              local winnr = vim.api.nvim_get_current_win()
              clear_buffer(bufnr, winnr)
            end,
          })
        end,
      })
    end
  end
end

return {
  setup = setup,
}
