local cursor_group = vim.api.nvim_create_augroup("RestoreCursorShapeOnExit", { clear = true })
vim.api.nvim_create_autocmd("VimLeave", {
  group = cursor_group,
  command = "set guicursor=a:hor1",
})

local quit_group = vim.api.nvim_create_augroup("QuitAfterLastNormalWindow", { clear = true })
vim.api.nvim_create_autocmd("QuitPre", {
  group = quit_group,
  callback = function()
    local current_win = vim.api.nvim_get_current_win()
    local current_buf = vim.api.nvim_win_get_buf(current_win)
    if vim.bo[current_buf].buftype ~= "" then
      return
    end

    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if win ~= current_win then
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].buftype == "" then
          return
        end
      end
    end

    vim.schedule(function()
      if vim.api.nvim_win_is_valid(current_win) then
        return
      end

      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].buftype == "" then
          return
        end
      end

      local ok, err = pcall(vim.cmd.quitall)
      if not ok then
        vim.notify(err, vim.log.levels.ERROR)
      end
    end)
  end,
  desc = "Quit after closing the last normal window",
})
