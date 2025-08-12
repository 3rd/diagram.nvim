local image_nvim = require("image")

local M = {}

---@param bufnr number
---@param integrations Integration[]
---@return Diagram|nil
local get_diagram_at_cursor = function(bufnr, integrations)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1 -- 0-indexed
  local col = cursor[2]
  
  -- Find matching integration for current filetype
  local ft = vim.bo[bufnr].filetype
  local integration = nil
  for _, integ in ipairs(integrations) do
    if vim.tbl_contains(integ.filetypes, ft) then
      integration = integ
      break
    end
  end
  
  if not integration then return nil end
  
  local diagrams = integration.query_buffer_diagrams(bufnr)
  for _, diagram in ipairs(diagrams) do
    if row >= diagram.range.start_row and row <= diagram.range.end_row then
      return diagram
    end
  end
  
  return nil
end

---@param diagram Diagram
---@param integrations Integration[]
---@param renderer_options table<string, any>
M.show_diagram_hover = function(diagram, integrations, renderer_options)
  -- Find matching integration for current filetype
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  local integration = nil
  for _, integ in ipairs(integrations) do
    if vim.tbl_contains(integ.filetypes, ft) then
      integration = integ
      break
    end
  end
  
  if not integration then return end
  
  -- Find renderer
  local renderer = nil
  for _, r in ipairs(integration.renderers) do
    if r.id == diagram.renderer_id then
      renderer = r
      break
    end
  end
  
  if not renderer then
    vim.notify("No renderer found for " .. diagram.renderer_id, vim.log.levels.ERROR)
    return
  end
  
  -- Render the diagram
  local options = renderer_options[renderer.id] or {}
  local renderer_result = renderer.render(diagram.source, options)
  
  local function show_in_tab()
    if vim.fn.filereadable(renderer_result.file_path) == 0 then
      vim.notify("Diagram file not found: " .. renderer_result.file_path, vim.log.levels.ERROR)
      return
    end
    
    -- Create a new tab for better image.nvim support
    vim.cmd("tabnew")
    local buf = vim.api.nvim_get_current_buf()
    local win = vim.api.nvim_get_current_win()
    
    -- Set buffer options
    vim.api.nvim_buf_set_name(buf, diagram.renderer_id .. " diagram")
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    
    -- Add header content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "# " .. diagram.renderer_id:upper() .. " Diagram",
      "",
      "Press 'q' to close this tab",
      "Press 'o' to open image with system viewer",
      "",
    })
    
    -- Try to render the image
    local image = image_nvim.from_file(renderer_result.file_path, {
      buffer = buf,
      window = win,
      with_virtual_padding = true,
      inline = true,
      x = 0,
      y = 5, -- Start after the header text
    })
    
    if image then
      image:render()
    else
      -- Fallback if image.nvim fails
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, {
        "Image display failed. File: " .. renderer_result.file_path,
      })
    end
    
    -- Keymaps for the diagram tab
    vim.keymap.set("n", "q", function()
      if image then image:clear() end
      vim.cmd("tabclose")
    end, { buffer = buf, desc = "Close diagram tab" })
    
    vim.keymap.set("n", "<Esc>", function()
      if image then image:clear() end
      vim.cmd("tabclose")
    end, { buffer = buf, desc = "Close diagram tab" })
    
    vim.keymap.set("n", "o", function()
      vim.fn.system("open " .. vim.fn.shellescape(renderer_result.file_path))
    end, { buffer = buf, desc = "Open image with system viewer" })
  end
  
  if renderer_result.job_id then
    -- Wait for async rendering
    local timer = vim.loop.new_timer()
    if not timer then return end
    timer:start(0, 100, vim.schedule_wrap(function()
      local result = vim.fn.jobwait({ renderer_result.job_id }, 0)
      if result[1] ~= -1 then
        if timer:is_active() then
          timer:stop()
        end
        if not timer:is_closing() then
          timer:close()
          show_in_tab()
        end
      end
    end))
  else
    show_in_tab()
  end
end

---@param integrations Integration[]
---@param renderer_options table<string, any>
M.hover_at_cursor = function(integrations, renderer_options)
  local bufnr = vim.api.nvim_get_current_buf()
  local diagram = get_diagram_at_cursor(bufnr, integrations)
  
  if not diagram then
    vim.notify("No diagram found at cursor", vim.log.levels.INFO)
    return
  end
  
  M.show_diagram_hover(diagram, integrations, renderer_options)
end

return M