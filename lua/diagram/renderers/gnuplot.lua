---@class GnuplotOptions
---@field size? string      -- output size (e.g. "800,600")
---@field font? string      -- font settings
---@field theme? string     -- light/dark theme settings
---@field cli_args? string[]

---@type table<string, string>
local cache = {} -- session cache

---@class Renderer<GnuplotOptions>
local M = {
  id = "gnuplot",
}

-- fs cache
local tmpdir = vim.fn.resolve(vim.fn.stdpath("cache") .. "/diagram-cache/gnuplot")
vim.fn.mkdir(tmpdir, "p")

---@param source string
---@param options GnuplotOptions
---@return table|nil
M.render = function(source, options)
  local hash = vim.fn.sha256(M.id .. ":" .. source)
  if cache[hash] then return cache[hash] end

  local path = vim.fn.resolve(tmpdir .. "/" .. hash .. ".png")
  if vim.fn.filereadable(path) == 1 then return { file_path = path } end

  if not vim.fn.executable("gnuplot") then
    vim.notify("gnuplot not found in PATH. Please install gnuplot to use gnuplot diagrams.", vim.log.levels.ERROR, { title = "Diagram.nvim" })
    return nil
  end

  local tmpsource = vim.fn.tempname()

  -- Prepare gnuplot script with output settings
  local script = {}
  table.insert(script, "set terminal pngcairo")
  table.insert(script, string.format("set output '%s'", path))

  if options.size then table.insert(script, string.format("set size %s", options.size)) end

  if options.font then table.insert(script, string.format("set terminal pngcairo font '%s'", options.font)) end

  -- Add theme settings
  if options.theme == "dark" then
    table.insert(
      script,
      [[
        set linetype 1 lc rgb "#377EB8"
        set linetype 2 lc rgb "#4DAF4A"
        set linetype 3 lc rgb "#E41A1C"
        set border lc rgb "#FFFFFF"
        set grid lc rgb "#404040"
        set key tc rgb "#FFFFFF"
        set tics tc rgb "#FFFFFF"
        set object 1 rectangle from screen 0,0 to screen 1,1 behind fillcolor rgb "#000000" fillstyle solid 1.0
        ]]
    )
  elseif options.theme == "light" or options.theme == nil then
    table.insert(
      script,
      [[
        set linetype 1 lc rgb "#377EB8"
        set linetype 2 lc rgb "#4DAF4A"
        set linetype 3 lc rgb "#E41A1C"
        set border lc rgb "#000000"
        set grid lc rgb "#D3D3D3"
        set key tc rgb "#000000"
        set tics tc rgb "#000000"
        set object 1 rectangle from screen 0,0 to screen 1,1 behind fillcolor rgb "#FFFFFF" fillstyle solid 1.0
        ]]
    )
  elseif type(options.theme) == "string" then
    -- treat as a custom theme
    table.insert(script, options.theme)
  elseif options.theme ~= nil then
    vim.notify("Invalid gnuplot theme option. Must be 'light', 'dark', or a custom theme string.", vim.log.levels.ERROR, { title = "Diagram.nvim" })
    return nil
  end

  -- Add the user's source plot commands
  table.insert(script, source)

  -- Write the complete script to temporary file
  vim.fn.writefile(vim.split(table.concat(script, "\n"), "\n"), tmpsource)

  -- Build command with optional cli_args
  local command_parts = { "gnuplot" }

  -- Add custom CLI arguments if provided
  if options.cli_args and #options.cli_args > 0 then vim.list_extend(command_parts, options.cli_args) end

  -- Add the script file
  table.insert(command_parts, tmpsource)

  local command = table.concat(command_parts, " ")
  local job_id = vim.fn.jobstart(command, {
    on_stdout = function(job_id, data, event) end,
    on_stderr = function(job_id, data, event)
      local error_msg = table.concat(data, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
      if error_msg ~= "" then
        vim.notify("Failed to render gnuplot diagram:\n" .. error_msg, vim.log.levels.ERROR, { title = "Diagram.nvim" })
      end
    end,
    on_exit = function(job_id, exit_code, event)
      -- Clean up temporary script file
      vim.fn.delete(tmpsource)
      cache[hash] = path
      -- local msg = string.format("Job %d exited with code %d.", job_id, exit_code)
      -- vim.api.nvim_out_write(msg .. "\n")
    end,
  })

  return { file_path = path, job_id = job_id }
end

return M
