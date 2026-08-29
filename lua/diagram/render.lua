local Controller = {}
Controller.__index = Controller

local function target_key(bufnr, winnr, integration)
  return table.concat({ bufnr, winnr, integration.id }, ":")
end

local function image_key(target, diagram)
  return table.concat({ target, diagram.renderer_id, diagram.range.start_row, diagram.range.start_col }, ":")
end

local function default_defer(callback, delay)
  vim.defer_fn(callback, delay)
end

local function default_job_status(job_id)
  return vim.fn.jobwait({ job_id }, 0)[1]
end

local function default_job_stop(job_id)
  vim.fn.jobstop(job_id)
end

---@param image_api table
---@param dependencies? table
---@return table
function Controller.new(image_api, dependencies)
  local deps = dependencies or {}
  return setmetatable({
    image_api = image_api,
    defer = deps.defer or default_defer,
    job_status = deps.job_status or default_job_status,
    job_stop = deps.job_stop or default_job_stop,
    file_readable = deps.file_readable or function(path) return vim.fn.filereadable(path) == 1 end,
    buffer_valid = deps.buffer_valid or vim.api.nvim_buf_is_valid,
    window_valid = deps.window_valid or vim.api.nvim_win_is_valid,
    filetype = deps.filetype or function(bufnr) return vim.bo[bufnr].filetype end,
    debounce_ms = deps.debounce_ms or 25,
    poll_ms = deps.poll_ms or 100,
    generation = 0,
    requests = {},
    diagrams = {},
  }, Controller)
end

function Controller:_is_current(target, request)
  local current = self.requests[target]
  return current ~= nil and current.generation == request.generation
end

function Controller:_cancel_request(target)
  local request = self.requests[target]
  if not request then return end

  self.requests[target] = nil
  for job_id in pairs(request.jobs) do
    self.job_stop(job_id)
  end
end

function Controller:_clear_target(target)
  for key, rendered in pairs(self.diagrams) do
    if rendered.target == target then
      if rendered.image then rendered.image:clear() end
      self.diagrams[key] = nil
    end
  end
end

---@param bufnr number
function Controller:clear_buffer(bufnr)
  for target, request in pairs(self.requests) do
    if request.bufnr == bufnr then self:_cancel_request(target) end
  end

  for key, rendered in pairs(self.diagrams) do
    if rendered.bufnr == bufnr then
      if rendered.image then rendered.image:clear() end
      self.diagrams[key] = nil
    end
  end
end

function Controller:_render_image(target, request, diagram, renderer_result)
  if not self:_is_current(target, request) then return end
  if not self.buffer_valid(request.bufnr) or not self.window_valid(request.winnr) then return end
  if not self.file_readable(renderer_result.file_path) then return end

  local row = diagram.range.start_row
  if self.filetype(request.bufnr) == "norg" then row = row - 1 end

  local key = image_key(target, diagram)
  local previous = self.diagrams[key]
  if previous and previous.image then previous.image:clear() end

  local image = self.image_api.from_file(renderer_result.file_path, {
    id = "diagram:" .. key,
    buffer = request.bufnr,
    window = request.winnr,
    with_virtual_padding = true,
    inline = true,
    x = diagram.range.start_col,
    y = row,
    render_offset_top = 1,
  })
  if not image then return end

  diagram.image = image
  self.diagrams[key] = {
    target = target,
    bufnr = request.bufnr,
    image = image,
  }
  image:render()
end

function Controller:_wait_for_job(target, request, diagram, renderer_result)
  local job_id = renderer_result.job_id
  request.jobs[job_id] = true

  local function poll()
    if not self:_is_current(target, request) then return end

    local status = self.job_status(job_id)
    if status == -1 then
      self.defer(poll, self.poll_ms)
      return
    end

    request.jobs[job_id] = nil
    if status == 0 then self:_render_image(target, request, diagram, renderer_result) end
  end

  self.defer(poll, 0)
end

function Controller:_render(target, request, integration, renderer_options)
  if not self:_is_current(target, request) then return end
  if not self.buffer_valid(request.bufnr) or not self.window_valid(request.winnr) then
    self:_cancel_request(target)
    self:_clear_target(target)
    return
  end

  local renderers = {}
  for _, renderer in ipairs(integration.renderers) do
    renderers[renderer.id] = renderer
  end

  for _, diagram in ipairs(integration.query_buffer_diagrams(request.bufnr)) do
    local renderer = renderers[diagram.renderer_id]
    if not renderer then
      vim.notify(
        "Unknown diagram renderer: " .. diagram.renderer_id,
        vim.log.levels.ERROR,
        { title = "Diagram.nvim" }
      )
      goto continue
    end

    local result = renderer.render(diagram.source, renderer_options[renderer.id] or {})
    if not result then goto continue end

    if result.job_id then
      self:_wait_for_job(target, request, diagram, result)
    else
      self:_render_image(target, request, diagram, result)
    end

    ::continue::
  end
end

---@param bufnr number
---@param winnr number
---@param integration Integration
---@param renderer_options table<string, any>
function Controller:queue(bufnr, winnr, integration, renderer_options)
  local target = target_key(bufnr, winnr, integration)
  self:_cancel_request(target)
  self:_clear_target(target)

  self.generation = self.generation + 1
  local request = {
    bufnr = bufnr,
    winnr = winnr,
    generation = self.generation,
    jobs = {},
  }
  self.requests[target] = request

  self.defer(function()
    self:_render(target, request, integration, renderer_options)
  end, self.debounce_ms)
end

return Controller
