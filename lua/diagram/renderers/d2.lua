---@class D2Options
---@field theme_id? number
---@field dark_theme_id? number
---@field scale? number
---@field layout? string
---@field sketch? boolean
---@field cli_args? string[]

---@type table<string, string>

---@class Renderer<D2Options>
local M = {
  id = "d2",
}

-- fs cache
local cache_dir = vim.fn.resolve(vim.fn.stdpath("cache") .. "/diagram-cache/d2")
vim.fn.mkdir(cache_dir, "p")

---@param source string
---@param options D2Options
---@return table|nil
M.render = function(source, options)
  local hash = vim.fn.sha256(M.id .. ":" .. source)

  local path = vim.fn.resolve(cache_dir .. "/" .. hash .. ".png")
  if vim.fn.filereadable(path) == 1 then return { file_path = path } end

  if not vim.fn.executable("d2") then
    vim.notify("d2 not found in PATH. Please install D2 to use D2 diagrams.", vim.log.levels.ERROR, { title = "Diagram.nvim" })
    return nil
  end

  local tmpsource = vim.fn.tempname()
  vim.fn.writefile(vim.split(source, "\n"), tmpsource)

  local command_parts = {
    "d2",
  }

  -- Add custom CLI arguments if provided
  if options.cli_args and #options.cli_args > 0 then vim.list_extend(command_parts, options.cli_args) end

  -- Add input and output files
  table.insert(command_parts, tmpsource)
  table.insert(command_parts, path)

  -- Add standard options
  if options.theme_id then
    table.insert(command_parts, "-t")
    table.insert(command_parts, options.theme_id)
  end
  if options.dark_theme_id then
    table.insert(command_parts, "--dark-theme")
    table.insert(command_parts, options.dark_theme_id)
  end
  if options.scale then
    table.insert(command_parts, "--scale")
    table.insert(command_parts, options.scale)
  end
  if options.layout then
    table.insert(command_parts, "--layout")
    table.insert(command_parts, options.layout)
  end
  if options.sketch then table.insert(command_parts, "-s") end

  local command = table.concat(command_parts, " ")

  local job_id = vim.fn.jobstart(command, {
    on_stdout = function(job_id, data, event) end,
    on_stderr = function(job_id, data, event)
      local error_msg = table.concat(data, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
      if error_msg ~= "" then
        vim.notify("Failed to render D2 diagram:\n" .. error_msg, vim.log.levels.ERROR, { title = "Diagram.nvim" })
      end
    end,
    on_exit = function(job_id, exit_code, event)
      -- local msg = string.format("Job %d exited with code %d.", job_id, exit_code)
      -- vim.api.nvim_out_write(msg .. "\n")
    end,
  })

  return { file_path = path, job_id = job_id }
end

return M
