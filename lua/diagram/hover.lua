local image_nvim = require("image")

local M = {}

local show_loading_notification = function(diagram_type)
  vim.notify("Loading " .. diagram_type .. " diagram...", vim.log.levels.INFO, {
    timeout = 5000,
  })
end

local show_ready_notification = function()
  vim.notify("✓ Diagram ready", vim.log.levels.INFO, {
    replace = true,
    timeout = 1500,
  })
end

-- Helper function to calculate the full code block range from existing diagram data
local get_extended_range = function(bufnr, diagram)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local start_row = diagram.range.start_row
  local end_row = diagram.range.end_row

  -- Look backwards from start_row to find the opening ```
  for i = start_row, 0, -1 do
    local line = lines[i + 1] -- Lua is 1-indexed, TreeSitter is 0-indexed
    if line and line:match("^%s*```") then
      start_row = i
      break
    end
  end

  -- Look forwards to find the closing ```
  for i = end_row, #lines - 1 do
    local line = lines[i + 1] -- Lua is 1-indexed, TreeSitter is 0-indexed
    if line and line:match("^%s*```%s*$") then
      end_row = i
      break
    end
  end

  return {
    start_row = start_row,
    start_col = 0,
    end_row = end_row,
    end_col = 0,
  }
end

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
    -- Expand the detection range to include the entire code block
    local extended_range = get_extended_range(bufnr, diagram)

    if row >= extended_range.start_row and row <= extended_range.end_row then return diagram end
  end

  return nil
end

--- Get the dimensions of an image file
---@param file_path string
---@return {width: number, height: number}|nil
local get_image_dimensions = function(file_path)
  -- Try using ImageMagick's identify command
  local handle = io.popen(string.format('identify -format "%%w %%h" "%s" 2>/dev/null', file_path))
  if handle then
    local result = handle:read("*a")
    handle:close()
    if result and result:match("%d+%s+%d+") then
      local width, height = result:match("(%d+)%s+(%d+)")
      if width and height then
        return {
          width = tonumber(width),
          height = tonumber(height),
        }
      end
    end
  end

  -- Fallback: try to use image.lua to get dimensions
  local success, image_module = pcall(require, "image")
  if success and image_module then
    local temp_image = image_module.from_file(file_path)
    if temp_image and temp_image.image_width and temp_image.image_height then
      local dims = {
        width = temp_image.image_width,
        height = temp_image.image_height,
      }
      temp_image:clear()
      return dims
    end
  end

  return nil
end

--- Calculate popup window size based on image dimensions
---@param image_dims {width: number, height: number}|nil
---@param popup_config table<string, any>
---@return number popup_width
---@return number popup_height
local calculate_popup_size = function(image_dims, popup_config)
  local term_size = require("image.utils.term").get_size()
  local term_cols = term_size.screen_cols or 80
  local term_rows = term_size.screen_rows or 24
  local cell_width = term_size.cell_width or 10
  local cell_height = term_size.cell_height or 20

  -- Max size: 90% of terminal
  local max_width = math.floor(term_cols * 0.9)
  local max_height = math.floor(term_rows * 0.9)

  if not image_dims then
    -- Fallback: use half of window
    return popup_config.width or math.floor(term_cols / 2),
      popup_config.height or math.floor(term_rows / 2)
  end

  local image_math = require("image.utils.math")

  -- Convert image pixels to terminal cells
  local image_cols = math.floor(image_dims.width / cell_width)
  local image_rows = math.floor(image_dims.height / cell_height)

  -- Check if image exceeds max size
  if image_cols > max_width or image_rows > max_height then
    -- Scale down to fit, maintaining aspect ratio
    if image_cols / max_width > image_rows / max_height then
      -- Width is the limiting factor
      return image_math.adjust_to_aspect_ratio(
        term_size, image_dims.width, image_dims.height, max_width, 0
      )
    else
      -- Height is the limiting factor
      return image_math.adjust_to_aspect_ratio(
        term_size, image_dims.width, image_dims.height, 0, max_height
      )
    end
  end

  -- Image fits, use its natural size
  return image_cols, image_rows
end

---@param diagram Diagram
---@param integrations Integration[]
---@param renderer_options table<string, any>
---@param popup_config table<string, any>
M.show_diagram_hover = function(diagram, integrations, renderer_options, popup_config)
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

  local function show_in_popup()
    if vim.fn.filereadable(renderer_result.file_path) == 0 then
      vim.notify("Diagram file not found: " .. renderer_result.file_path, vim.log.levels.ERROR)
      return
    end

    show_ready_notification()

    local image_dims = get_image_dimensions(renderer_result.file_path)
    local popup_width, popup_height = calculate_popup_size(image_dims, popup_config)

    -- Create a new buffer for the popup
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "diagram_popup"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false

    -- Create the popup window
    local win = vim.api.nvim_open_win(buf, false, {
      relative = "cursor",
      row = 1,
      col = 0,
      width = popup_width,
      height = popup_height,
      style = "minimal",
      border = "single",
    })

    -- Create image
    local image = image_nvim.from_file(renderer_result.file_path, {
      buffer = buf,
      window = win,
      with_virtual_padding = false,
      namespace = "diagram_popup",
    })

    if image then
      image.ignore_global_max_size = true
      -- Render after window is open (same as image.nvim)
      vim.defer_fn(function()
        if vim.api.nvim_win_is_valid(win) then
          image:render({
            x = 0,
            y = 0,
            width = popup_width,
            height = popup_height,
          })
        end
      end, 10)
    else
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "Diagram: " .. diagram.renderer_id,
        "",
        "File: " .. renderer_result.file_path,
        "",
        "Image display failed in popup.",
      })
    end

    -- Store popup data for cleanup
    M._current_popup = {
      window = win,
      buffer = buf,
      image = image,
      auto_close = popup_config.auto_close ~= false,
    }

    -- Keymaps
    vim.keymap.set("n", "q", function() M.close_popup() end, { buffer = buf, desc = "Close diagram popup" })
    vim.keymap.set("n", "<Esc>", function() M.close_popup() end, { buffer = buf, desc = "Close diagram popup" })
    vim.keymap.set("n", "o", function() vim.ui.open(renderer_result.file_path) end, { buffer = buf, desc = "Open image with system viewer" })

    -- Auto-close on cursor move
    if popup_config.auto_close ~= false then
      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        callback = function()
          if M._current_popup and vim.api.nvim_win_is_valid(M._current_popup.window) then
            M.close_popup()
          end
        end,
        once = true,
        desc = "Auto-close diagram popup on cursor move",
      })
    end
  end

  local function show_in_tab()
    if vim.fn.filereadable(renderer_result.file_path) == 0 then
      vim.notify("Diagram file not found: " .. renderer_result.file_path, vim.log.levels.ERROR)
      return
    end

    -- Show ready notification to replace loading message
    show_ready_notification()

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
      vim.ui.open(renderer_result.file_path)
    end, { buffer = buf, desc = "Open image with system viewer" })
  end

  if renderer_result.job_id then
    -- Wait for async rendering
    local timer = vim.loop.new_timer()
    if not timer then return end
    timer:start(
      0,
      100,
      vim.schedule_wrap(function()
        local result = vim.fn.jobwait({ renderer_result.job_id }, 0)
        if result[1] ~= -1 then
          if timer:is_active() then timer:stop() end
          if not timer:is_closing() then
            timer:close()
            if popup_config and popup_config.enabled then
              show_in_popup()
            else
              show_in_tab()
            end
          end
        end
      end)
    )
  else
    if popup_config and popup_config.enabled then
      show_in_popup()
    else
      show_in_tab()
    end
  end
end

---@param integrations Integration[]
---@param renderer_options table<string, any>
---@param popup_config table<string, any>
M.hover_at_cursor = function(integrations, renderer_options, popup_config)
  local bufnr = vim.api.nvim_get_current_buf()
  local diagram = get_diagram_at_cursor(bufnr, integrations)

  if not diagram then
    vim.notify("No diagram found at cursor", vim.log.levels.INFO)
    return
  end

  show_loading_notification(diagram.renderer_id)
  M.show_diagram_hover(diagram, integrations, renderer_options, popup_config)
end

--- Close the current popup window
M.close_popup = function()
  if M._current_popup then
    local popup = M._current_popup

    -- Clear the image
    if popup.image then
      popup.image:clear()
    end

    -- Close the window
    if vim.api.nvim_win_is_valid(popup.window) then
      vim.api.nvim_win_close(popup.window, true)
    end

    -- Clear the buffer
    if vim.api.nvim_buf_is_valid(popup.buffer) then
      vim.api.nvim_buf_delete(popup.buffer, { force = true })
    end

    -- Reset the reference
    M._current_popup = nil
  end
end

--- Get the diagram at the current cursor position
---@param bufnr number
---@param integrations Integration[]
---@return Diagram|nil
M.get_diagram_at_cursor = function(bufnr, integrations)
  return get_diagram_at_cursor(bufnr, integrations)
end

return M
