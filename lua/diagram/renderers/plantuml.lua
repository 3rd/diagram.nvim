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
---@param on_finish? function
---@return table|nil
M.render = function(source, options, on_finish)
	local hash = vim.fn.sha256(M.id .. ":" .. source .. ":" .. vim.inspect(options))

	local path = vim.fn.resolve(cache_dir .. "/" .. hash .. ".png")
	if vim.fn.filereadable(path) == 1 then
		return { file_path = path }
	end

	if not vim.fn.executable("plantuml") then
		vim.notify(
			"plantuml not found in PATH. Please install PlantUML to use PlantUML diagrams.",
			vim.log.levels.ERROR,
			{ title = "Diagram.nvim" }
		)
		return nil
	end

	local tmpsource = vim.fn.tempname()
	vim.fn.writefile(vim.split(source, "\n"), tmpsource)

	local command_parts = {
		"plantuml",
	}

	-- Add custom CLI arguments if provided
	if options.cli_args and #options.cli_args > 0 then
		vim.list_extend(command_parts, options.cli_args)
	end

	-- Add standard arguments
	vim.list_extend(command_parts, {
		"-tpng",
	})

	if options.charset then
		table.insert(command_parts, "-charset")
		table.insert(command_parts, options.charset)
	end
	table.insert(command_parts, tmpsource)

	local job_id = vim.fn.jobstart(command_parts, {
		on_stdout = function(job_id, data, event) end,
		on_stderr = function(job_id, data, event)
			local error_msg = table.concat(data, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
			if error_msg ~= "" then
				vim.notify(
					"Failed to render PlantUML diagram:\n" .. error_msg,
					vim.log.levels.ERROR,
					{ title = "Diagram.nvim" }
				)
			end
		end,
		on_exit = function(job_id, exit_code, event)
			local generated_file = tmpsource .. ".png"
			if vim.fn.filereadable(generated_file) == 1 then
				vim.fn.rename(generated_file, path)
			end
			vim.fn.delete(tmpsource)
			if on_finish then
				on_finish()
			end
		end,
	})

	return { file_path = path, job_id = job_id }
end

return M
