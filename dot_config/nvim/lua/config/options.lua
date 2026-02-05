-- About File
vim.opt.fileencoding = "utf-8"
vim.opt.swapfile = false -- Do not create swapfiile
vim.opt.hidden = true

-- Do not use clipboard
vim.opt.formatoptions:remove("r")
vim.opt.formatoptions:remove("o")

-- Menu and command
vim.opt.wildmenu = true
vim.opt.cmdheight = 1
vim.opt.showcmd = true

-- Status Line
vim.opt.laststatus = 3

-- Search and Replace
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.matchtime = 1

-- Color Scheme
vim.opt.termguicolors = true
vim.opt.background = "dark"

-- Display
-- Indent

-- Disable wrap test
vim.opt.wrap = false
-- Display tabline
vim.opt.showtabline = 2
-- highlights
vim.opt.showmatch = true
vim.opt.list = true

-- Interface
-- Opacity
vim.opt.pumblend = 20
-- Sub Columns
vim.opt.showtabline = 2
vim.opt.signcolumn = "yes"

-- Suppress
vim.opt.report = 100
vim.opt.shortmess:append({
  W = true, -- "written" message
  I = true, -- Intro message
  c = true, -- completion messages
})

-- API quiting
vim.api.nvim_create_autocmd("QuitPre", {
  callback = function()
    local current_win = vim.api.nvim_get_current_win()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if win ~= current_win then
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].buftype == "" then
          return
        end
      end
    end
    vim.cmd.only({ bang = true })
  end,
  desc = "Close all special buffers and quit Neovim",
})
