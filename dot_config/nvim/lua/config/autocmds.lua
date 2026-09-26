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

local autosync_group = vim.api.nvim_create_augroup("DotfilesAutosync", { clear = true })

local function launch_dotfiles_autosync()
  local script = vim.fn.expand("~/.local/bin/dotfiles-autosync.sh")

  if vim.fn.executable(script) ~= 1 then
    return
  end

  vim.fn.jobstart({ script, "nvim" }, { detach = true })
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = autosync_group,
  callback = launch_dotfiles_autosync,
  desc = "Detach the dotfiles auto-sync after Neovim exits",
})

vim.api.nvim_create_autocmd("User", {
  group = autosync_group,
  pattern = "LazySync",
  callback = function()
    vim.defer_fn(launch_dotfiles_autosync, 3000)
  end,
  desc = "Detach the dotfiles auto-sync three seconds after a lazy sync",
})
