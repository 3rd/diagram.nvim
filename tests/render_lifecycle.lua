vim.opt.runtimepath:prepend(vim.fn.getcwd())

local Controller = require("diagram/render")

local function assert_equal(expected, actual, message)
  if not vim.deep_equal(expected, actual) then
    error((message or "values differ") .. "\nexpected: " .. vim.inspect(expected) .. "\nactual: " .. vim.inspect(actual))
  end
end

local function harness()
  local scheduled = {}
  local statuses = {}
  local stopped = {}
  local created = {}
  local rendered = {}
  local cleared = {}

  local image_api = {
    from_file = function(path, opts)
      table.insert(created, { path = path, opts = opts })
      local image = { id = opts.id }
      function image:render() table.insert(rendered, self.id) end
      function image:clear() table.insert(cleared, self.id) end
      return image
    end,
  }

  local controller = Controller.new(image_api, {
    debounce_ms = 25,
    poll_ms = 100,
    defer = function(callback, delay)
      table.insert(scheduled, { callback = callback, delay = delay })
    end,
    job_status = function(job_id) return statuses[job_id] or -1 end,
    job_stop = function(job_id) table.insert(stopped, job_id) end,
    file_readable = function() return true end,
    buffer_valid = function() return true end,
    window_valid = function() return true end,
    filetype = function() return "markdown" end,
  })

  local function run(index)
    local item = table.remove(scheduled, index or 1)
    assert(item, "expected a scheduled callback")
    item.callback()
    return item.delay
  end

  return {
    controller = controller,
    scheduled = scheduled,
    statuses = statuses,
    stopped = stopped,
    created = created,
    rendered = rendered,
    cleared = cleared,
    run = run,
  }
end

local function diagram(source, row)
  return {
    bufnr = 1,
    renderer_id = "mermaid",
    source = source,
    range = { start_row = row or 4, start_col = 0, end_row = (row or 4) + 1, end_col = 0 },
  }
end

local function test_duplicate_events_are_coalesced()
  local h = harness()
  local source = "old"
  local calls = {}
  local integration = {
    id = "markdown",
    renderers = {
      {
        id = "mermaid",
        render = function(value)
          table.insert(calls, value)
          return { file_path = "/cache/" .. value .. ".png" }
        end,
      },
    },
    query_buffer_diagrams = function() return { diagram(source) } end,
  }

  h.controller:queue(1, 2, integration, {})
  source = "new"
  h.controller:queue(1, 2, integration, {})

  h.run()
  h.run()

  assert_equal({ "new" }, calls, "only the latest coalesced event should invoke the renderer")
  assert_equal(1, #h.rendered, "only one image should render")
end

local function test_stale_async_completion_is_ignored()
  local h = harness()
  local source = "old"
  local next_job = 0
  local integration = {
    id = "markdown",
    renderers = {
      {
        id = "mermaid",
        render = function(value)
          next_job = next_job + 1
          return { file_path = "/cache/" .. value .. ".png", job_id = next_job }
        end,
      },
    },
    query_buffer_diagrams = function() return { diagram(source) } end,
  }

  h.controller:queue(1, 2, integration, {})
  h.run()
  source = "new"
  h.controller:queue(1, 2, integration, {})

  h.run(#h.scheduled)
  h.statuses[2] = 0
  h.run(#h.scheduled)
  h.statuses[1] = 0
  h.run()

  assert_equal({ 1 }, h.stopped, "the superseded job should be stopped")
  assert_equal(1, #h.created, "the stale job must not create an image")
  assert_equal("/cache/new.png", h.created[1].path, "the latest render should win")
end

local function test_stable_ids_replace_images()
  local h = harness()
  local integration = {
    id = "markdown",
    renderers = {
      {
        id = "mermaid",
        render = function() return { file_path = "/cache/diagram.png" } end,
      },
    },
    query_buffer_diagrams = function() return { diagram("same") } end,
  }

  h.controller:queue(1, 2, integration, {})
  h.run()
  h.controller:queue(1, 2, integration, {})
  h.run()

  assert_equal(h.created[1].opts.id, h.created[2].opts.id, "a diagram location should keep one image id")
  assert_equal({ h.created[1].opts.id }, h.cleared, "the previous image should be cleared before replacement")
end

local function test_multiple_diagrams_and_cleanup()
  local h = harness()
  local integration = {
    id = "markdown",
    renderers = {
      {
        id = "mermaid",
        render = function(value) return { file_path = "/cache/" .. value .. ".png" } end,
      },
    },
    query_buffer_diagrams = function() return { diagram("one", 4), diagram("two", 10) } end,
  }

  h.controller:queue(1, 2, integration, {})
  h.run()
  assert_equal(2, #h.created, "all diagrams should render")
  assert(h.created[1].opts.id ~= h.created[2].opts.id, "diagram locations should have distinct image ids")

  h.controller:queue(1, 3, integration, {})
  h.run()
  assert_equal(4, #h.created, "each window should own its diagram placements")
  assert(h.created[1].opts.id ~= h.created[3].opts.id, "windows should have distinct image ids")

  h.controller:clear_buffer(1)
  assert_equal(4, #h.cleared, "buffer cleanup should clear every rendered image")
end

local function test_cleanup_cancels_pending_jobs()
  local h = harness()
  local integration = {
    id = "markdown",
    renderers = {
      {
        id = "mermaid",
        render = function() return { file_path = "/cache/pending.png", job_id = 42 } end,
      },
    },
    query_buffer_diagrams = function() return { diagram("pending") } end,
  }

  h.controller:queue(1, 2, integration, {})
  h.run()
  h.controller:clear_buffer(1)
  h.statuses[42] = 0
  h.run()

  assert_equal({ 42 }, h.stopped, "buffer cleanup should stop pending jobs")
  assert_equal(0, #h.rendered, "a completion after cleanup must not render")
end

local tests = {
  test_duplicate_events_are_coalesced,
  test_stale_async_completion_is_ignored,
  test_stable_ids_replace_images,
  test_multiple_diagrams_and_cleanup,
  test_cleanup_cancels_pending_jobs,
}

for _, test in ipairs(tests) do test() end
print(string.format("diagram.nvim: %d render lifecycle tests passed", #tests))
