---@class MermaidOptions
---@field background? string
---@field theme? string
---@field scale? number
---@field width? number
---@field height? number

---@type table<string, string>

---@class Renderer<MermaidOptions>
local M = {
  id = "mermaid",
}

-- fs cache
local tmpdir = vim.fn.resolve(vim.fn.stdpath("cache") .. "/diagram-cache/mermaid")
vim.fn.mkdir(tmpdir, "p")

---@param source string
---@param options MermaidOptions
---@return string|nil
M.render = function(source, options)
  local hash = vim.fn.sha256(M.id .. ":" .. source)
  local path = vim.fn.resolve(tmpdir .. "/" .. hash .. ".png")
  if vim.fn.filereadable(path) == 1 then return path end

  if not vim.fn.executable("mmdc") then error("diagram/mermaid: mmdc not found in PATH") end

  local tmpsource = vim.fn.tempname()
  vim.fn.writefile(vim.split(source, "\n"), tmpsource)

  local command_parts = {
    "mmdc",
    "-i",
    tmpsource,
    "-o",
    path,
  }
  if options.background then
    table.insert(command_parts, "-b")
    table.insert(command_parts, options.background)
  end
  if options.theme then
    table.insert(command_parts, "-t")
    table.insert(command_parts, options.theme)
  end
  if options.scale then
    table.insert(command_parts, "-s")
    table.insert(command_parts, options.scale)
  end
  if options.width then
    table.insert(command_parts, "--width")
    table.insert(command_parts, options.width)
  end
  if options.height then
    table.insert(command_parts, "--height")
    table.insert(command_parts, options.height)
  end

  local command = table.concat(command_parts, " ")

  local function on_event(job_id, data, event)
    if data and #data > 0 then
      local msg = string.format("[%s] Job %d: %s", event, job_id, table.concat(data, "\n"))
      vim.api.nvim_out_write(msg .. "\n")
    end
  end

  vim.fn.jobstart(
    command,
    {
      on_stdout = function(job_id, data, event) on_event(job_id, data, "stdout") end,
      on_stderr = function(job_id, data, event) on_event(job_id, data, "stderr") end,
      on_exit = function(job_id, exit_code, event)
        local msg = string.format("Job %d exited with code %d.", job_id, exit_code)
        vim.api.nvim_out_write(msg .. "\n")
      end,
    }
  )
  -- if vim.v.shell_error ~= 0 then
  --   vim.notify("diagram/mermaid: mmdc failed to render diagram", vim.log.levels.ERROR)
  --   return nil
  -- end

  return path
end

return M
