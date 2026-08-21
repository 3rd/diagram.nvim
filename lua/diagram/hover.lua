local M = {}

local function show_loading_notification(diagram_type)
	vim.notify("Loading " .. diagram_type .. " diagram...", vim.log.levels.INFO, {
		timeout = 5000,
	})
end

local function show_ready_notification()
	vim.notify("✓ Diagram ready", vim.log.levels.INFO, {
		replace = true,
		timeout = 1500,
	})
end

local function native_image(file_path, win, line)
	if not vim.ui.img or not vim.ui.img.set then
		return nil
	end

	local ok, data = pcall(vim.fn.readblob, file_path)
	if not ok then
		return nil
	end

	local id
	local image = {}

	function image:render()
		if not vim.api.nvim_win_is_valid(win) then
			return
		end

		local position = vim.fn.screenpos(win, line, 1)
		if position.row == 0 or position.col == 0 then
			return
		end

		if id then
			vim.ui.img.set(id, {
				row = position.row,
				col = position.col,
			})
			return
		end

		id = vim.ui.img.set(data, {
			row = position.row,
			col = position.col,
			zindex = 50,
		})
	end

	function image:clear()
		if id then
			vim.ui.img.del(id)
			id = nil
		end
	end

	return image
end

local function fallback_image(file_path, buf, win, line)
	local ok, image_nvim = pcall(require, "image")
	if not ok then
		return nil
	end

	return image_nvim.from_file(file_path, {
		buffer = buf,
		window = win,
		with_virtual_padding = true,
		inline = true,
		x = 0,
		y = line - 1,
	})
end

local function display_image(file_path, buf, win, line)
	local image = native_image(file_path, win, line) or fallback_image(file_path, buf, win, line)

	if image then
		image:render()
	end

	return image
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

	if not integration then
		return nil
	end

	local diagrams = integration.query_buffer_diagrams(bufnr)
	for _, diagram in ipairs(diagrams) do
		-- Expand the detection range to include the entire code block
		local extended_range = get_extended_range(bufnr, diagram)

		if row >= extended_range.start_row and row <= extended_range.end_row then
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

	if not integration then
		return
	end

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
	local renderer_result

	local function show_in_tab()
		if not renderer_result or vim.fn.filereadable(renderer_result.file_path) == 0 then
			vim.notify(
				"Diagram file not found: " .. (renderer_result and renderer_result.file_path or "nil"),
				vim.log.levels.ERROR
			)
			return
		end

		show_ready_notification()

		vim.cmd("tabnew")
		local buf = vim.api.nvim_get_current_buf()
		local win = vim.api.nvim_get_current_win()

		vim.api.nvim_buf_set_name(buf, diagram.renderer_id .. " diagram")
		vim.bo[buf].buftype = "nofile"
		vim.bo[buf].bufhidden = "wipe"
		vim.bo[buf].swapfile = false

		vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
			"# " .. diagram.renderer_id:upper() .. " Diagram",
			"",
			"Press 'q' to close this tab",
			"Press 'o' to open image with system viewer",
			"",
		})

		local image = display_image(renderer_result.file_path, buf, win, 6)

		if not image then
			vim.api.nvim_buf_set_lines(buf, -1, -1, false, {
				"Image display failed. File: " .. renderer_result.file_path,
			})
		end

		local function close()
			if image then
				image:clear()
			end
			vim.cmd("tabclose")
		end

		vim.keymap.set("n", "q", close, { buffer = buf, desc = "Close diagram tab" })
		vim.keymap.set("n", "<Esc>", close, { buffer = buf, desc = "Close diagram tab" })
		vim.keymap.set("n", "o", function()
			vim.ui.open(renderer_result.file_path)
		end, { buffer = buf, desc = "Open image with system viewer" })

		vim.api.nvim_create_autocmd({ "WinScrolled", "VimResized" }, {
			buffer = buf,
			callback = function()
				if image then
					vim.schedule(function()
						image:render()
					end)
				end
			end,
		})

		vim.api.nvim_create_autocmd("BufWipeout", {
			buffer = buf,
			once = true,
			callback = function()
				if image then
					image:clear()
				end
			end,
		})
	end

	renderer_result = renderer.render(diagram.source, options, function()
		vim.schedule(show_in_tab)
	end)

	if not renderer_result then
		return
	end

	if not renderer_result.job_id then
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

	show_loading_notification(diagram.renderer_id)
	M.show_diagram_hover(diagram, integrations, renderer_options)
end

return M
