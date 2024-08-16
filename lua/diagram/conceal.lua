---@param diagram Diagram
local apply_conceal = function(diagram)
  vim.api.nvim_buf_set_option(diagram.bufnr, "conceallevel", 2)
  vim.api.nvim_buf_set_option(diagram.bufnr, "concealcursor", "nc")

  diagram.conceal_namespace = vim.api.nvim_create_namespace("diagram.conceal:" .. diagram.bufnr)

  vim.api.nvim_buf_set_extmark(
    diagram.bufnr,
    diagram.conceal_namespace,
    diagram.range.start_row,
    diagram.range.start_col,
    {
      end_row = diagram.range.end_row,
      end_col = diagram.range.end_col,
      hl_group = "Error",
      conceal = "",
    }
  )
end

---@param diagram Diagram
local clear_conceal = function(diagram)
  if not diagram.conceal_namespace then return end
  vim.api.nvim_buf_clear_namespace(diagram.bufnr, diagram.conceal_namespace, 0, -1)
  diagram.conceal_namespace = nil
end

return {
  apply = apply_conceal,
  clear = clear_conceal,
}
