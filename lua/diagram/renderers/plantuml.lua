---@class PlantUMLOptions
---@field charset? string
---@field cli_args? string[]

---@type table<string, string>

---@class Renderer<PlantUMLOptions>
local M = {
  id = "plantuml",
}

-- fs cache
local cache_dir = vim.fn.resolve(vim.fn.stdpath("cache") .. "/diagram-cache/plantuml")
vim.fn.mkdir(cache_dir, "p")

---@param source string
---@param options PlantUMLOptions
---@return table|nil
M.render = function(source, options)
  local hash = vim.fn.sha256(M.id .. ":" .. source)

  local path = vim.fn.resolve(cache_dir .. "/" .. hash .. ".png")
  if vim.fn.filereadable(path) == 1 then return { file_path = path } end

  if not vim.fn.executable("plantuml") then
    vim.notify("plantuml not found in PATH. Please install PlantUML to use PlantUML diagrams.", vim.log.levels.ERROR, { title = "Diagram.nvim" })
    return nil
  end

  local tmpsource = vim.fn.tempname()
  vim.fn.writefile(vim.split(source, "\n"), tmpsource)

  local command_parts = {
    "plantuml",
  }

  -- Add custom CLI arguments if provided
  if options.cli_args and #options.cli_args > 0 then vim.list_extend(command_parts, options.cli_args) end

  -- Add standard arguments
  vim.list_extend(command_parts, {
    "-tpng",
    "-pipe",
  })

  if options.charset then
    table.insert(command_parts, "-charset")
    table.insert(command_parts, options.charset)
  end
  table.insert(command_parts, "<")
  table.insert(command_parts, tmpsource)

  local command = table.concat(command_parts, " ")

  local job_id = vim.fn.jobstart(
    command .. " > " .. vim.fn.shellescape(path .. ".new.png"), -- HACK: write to .new.png to prevent rendering a incomplete file
    {
      on_stdout = function(job_id, data, event) end,
      on_stderr = function(job_id, data, event)
        local error_msg = table.concat(data, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
        if error_msg ~= "" then
          vim.notify("Failed to render PlantUML diagram:\n" .. error_msg, vim.log.levels.ERROR, { title = "Diagram.nvim" })
        end
      end,
      on_exit = function(job_id, exit_code, event)
        -- local msg = string.format("Job %d exited with code %d.", job_id, exit_code)
        -- vim.api.nvim_out_write(msg .. "\n")
        vim.fn.rename(path .. ".new.png", path) -- HACK: rename to remove .new.png
      end,
    }
  )

  return { file_path = path, job_id = job_id }
end

return M
