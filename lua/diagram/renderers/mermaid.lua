---@class MermaidOptions
---@field background? string
---@field theme? string
---@field scale? number
---@field width? number
---@field height? number

---@type table<string, string>
local cache = {} -- session cache

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
  if cache[hash] then return cache[hash] end

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
  vim.fn.system(command)
  if vim.v.shell_error ~= 0 then
    vim.notify("diagram/mermaid: mmdc failed to render diagram", vim.log.levels.ERROR)
    return nil
  end

  cache[hash] = path
  return path
end

return M
