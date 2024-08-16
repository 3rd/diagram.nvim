---@class State
---@field integrations Integration[]
---@field diagrams Diagram[]
---@field renderer_options table<string, any>
---@field conceal_enable boolean

---@class PluginOptions
---@field integrations Integration[]
---@field renderer_options table<string, any>
---@field conceal_enable boolean

---@class Renderer<RenderOptions>
---@field id string
--- renders to a temp file and returns the path
---@field render fun(source: string, options?: RenderOptions): string

---@class IntegrationOptions
---@field filetypes string[]
---@field renderers Renderer[]

---@class Integration
---@field id string
---@field options IntegrationOptions
---@field query_buffer_diagrams fun(bufnr?: number): Diagram[]

---@class Diagram
---@field bufnr number
---@field range { start_row: number, start_col: number, end_row: number, end_col: number }
---@field renderer_id string
---@field source string
---@field image Image|nil
---@field conceal_namespace number|nil
