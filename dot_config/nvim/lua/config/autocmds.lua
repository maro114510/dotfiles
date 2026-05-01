local cursor_group = vim.api.nvim_create_augroup("RestoreCursorShapeOnExit", { clear = true })
vim.api.nvim_create_autocmd("VimLeave", {
  group = cursor_group,
  command = "set guicursor=a:hor1",
})
