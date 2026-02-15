---@class MermaidOptions
---@field background? string
---@field theme? string
---@field scale? number
---@field width? number
---@field height? number
---@field cli_args? string[]

---@type table<string, string>

---@class Renderer<MermaidOptions>
local M = {
	id = "mermaid",
}

-- fs cache
local cache_dir = vim.fn.resolve(vim.fn.stdpath("cache") .. "/diagram-cache/mermaid")
vim.fn.mkdir(cache_dir, "p")

---@param source string
---@param options MermaidOptions
---@param on_finish? function
---@return table|nil
M.render = function(source, options, on_finish)
	local hash = vim.fn.sha256(M.id .. ":" .. source .. ":" .. vim.inspect(options))
	local path = vim.fn.resolve(cache_dir .. "/" .. hash .. ".png")
	if vim.fn.filereadable(path) == 1 then
		return { file_path = path }
	end

	if not vim.fn.executable("mmdc") then
		vim.notify(
			"mmdc not found in PATH. Please install mermaid-cli to use mermaid diagrams.",
			vim.log.levels.ERROR,
			{ title = "Diagram.nvim" }
		)
		return nil
	end

	local tmpsource = vim.fn.tempname()
	vim.fn.writefile(vim.split(source, "\n"), tmpsource)

	local command_parts = {
		"mmdc",
	}

	-- Add custom CLI arguments if provided
	if options.cli_args and #options.cli_args > 0 then
		vim.list_extend(command_parts, options.cli_args)
	end

	-- Add standard arguments
	vim.list_extend(command_parts, {
		"-i",
		tmpsource,
		"-o",
		path,
	})
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

	local command = command_parts

	local job_id = vim.fn.jobstart(command, {
		on_stdout = function(job_id, data, event) end,
		on_stderr = function(job_id, data, event)
			local error_msg = table.concat(data, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
			if error_msg ~= "" then
				vim.notify(
					"Failed to render mermaid diagram:\n" .. error_msg,
					vim.log.levels.ERROR,
					{ title = "Diagram.nvim" }
				)
			end
		end,
		on_exit = function(job_id, exit_code, event)
			vim.fn.delete(tmpsource)
			if on_finish then
				on_finish()
			end
		end,
	})
	return { file_path = path, job_id = job_id }
end

return M
