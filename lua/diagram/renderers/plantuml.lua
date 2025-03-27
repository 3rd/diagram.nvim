---@class PlantUMLOptions
---@field charset? string

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

  if not vim.fn.executable("plantuml") then error("diagram/plantuml: plantuml not found in PATH") end

  local tmpsource = vim.fn.tempname()
  vim.fn.writefile(vim.split(source, "\n"), tmpsource)

  local command_parts = {
    "plantuml",
    "-tpng",
    "-pipe",
  }
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
        local error_msg = table.concat(data, "\n")
        vim.notify("diagram/plantuml: plantuml failed to render diagram.\nError: " .. error_msg, vim.log.levels.ERROR)
        return nil
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
