# Agent Guidelines for diagram.nvim

## Project Overview
Neovim plugin for rendering diagrams (mermaid, plantuml, d2, gnuplot) with pluggable renderers and integrations.

## Testing & Build
- No automated tests currently exist
- Manual testing: Load plugin in Neovim with `:luafile lua/diagram/init.lua` or via package manager
- Test integration: Create markdown file with mermaid/plantuml/d2/gnuplot code blocks

## Code Style

### Imports & Module Structure
- Use `require("module/path")` with forward slashes (e.g., `require("diagram/hover")`)
- Return modules as tables: `return M` or `return { setup = setup, ... }`
- Module definition: `local M = { id = "name" }` for renderers/integrations

### Types & Documentation
- Use LuaLS annotations extensively: `---@class`, `---@field`, `---@param`, `---@return`, `---@type`
- Define types in dedicated files (see `types.lua`) or at module top
- Example: `---@param source string` before function definitions

### Naming Conventions
- snake_case for functions, variables, fields: `render_buffer`, `query_buffer_diagrams`
- PascalCase for type definitions: `Renderer`, `Integration`, `PluginOptions`
- Lowercase for module IDs: `"mermaid"`, `"markdown"`

### Error Handling
- Use `vim.notify()` with `vim.log.levels.ERROR` and `{ title = "Diagram.nvim" }`
- Return `nil` from functions when executables not found (allows graceful degradation)
- Use `pcall` for optional dependencies: `local ok = pcall(require, "image")`
- Use `goto continue` pattern in loops to skip failed items

### Neovim API & Patterns
- Prefer `vim.api.nvim_*` functions over `vim.fn.*` where available
- Use treesitter for parsing: `vim.treesitter.get_parser()`, `vim.treesitter.query.parse()`
- Async jobs: `vim.fn.jobstart()` with callbacks, poll with `vim.loop.new_timer()`
- File operations: `vim.fn.writefile()`, `vim.fn.filereadable()`, `vim.fn.mkdir(cache, "p")`
- Cache in `vim.fn.stdpath("cache")` with SHA-256 hashing: `vim.fn.sha256()`
