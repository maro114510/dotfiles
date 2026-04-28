-- clipboard copy setting
vim.keymap.set("n", "x", '"_x')
vim.keymap.set("n", "s", '"_s')
vim.keymap.set("n", "d", '"_d')
vim.keymap.set("n", "D", '"_D')
vim.keymap.set("x", "d", '"_d')

vim.keymap.set("n", "ciw", 'viw"_c')

vim.keymap.set("n", "ss", ":split<Return><C-w>w")
vim.keymap.set("n", "sv", ":vsplit<Return><C-w>w")

-- change buffer files
vim.keymap.set("n", "<C-j>", "<cmd>bprev<CR>", { silent = true })
vim.keymap.set("n", "<C-k>", "<cmd>bnext<CR>", { silent = true })

-- move
vim.keymap.set("n", "j", "gj")
vim.keymap.set("n", "k", "gk")

-- yank
vim.keymap.set("n", "Y", "y$")

-- Esc
vim.keymap.set("i", "jj", "<ESC>", { silent = true })
vim.keymap.set("i", "っj", "<ESC>", { silent = true })

-- Exchange
vim.keymap.set("", ";", ":")

-- Telescope
vim.keymap.set(
  "n",
  "<C-f>",
  "<cmd>Telescope find_files find_command=rg,--files,--hidden,--glob,!*.git<cr>",
  { noremap = true, silent = true }
)

vim.keymap.set(
  "n",
  "<C-P>",
  -- "<cmd>Telescope find_files find_command=rg,--files,--hidden,--glob,!*.git<cr>",
  "<cmd>Telescope smart_open<CR>",
  { silent = true }
)
vim.keymap.set(
  "n",
  "<M-f>",
  "<cmd>Telescope lsp_dynamic_workspace_symbols find_command=rg,--files,--hidden,--glob,!*.git<cr>",
  -- '<cmd>lua require("fzf-lua").lsp_live_workspace_symbols()<CR>',
  { silent = true }
)
vim.keymap.set("n", "<C-g>", "<cmd>Telescope live_grep<cr>", { silent = true })

-- ToggleTerm
vim.keymap.set("n", "<C-T>", '<CMD>exe v:count1 . "ToggleTerm"<CR>', { silent = true })
-- exit terminal mode
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { silent = true })

-- NeoTree
vim.keymap.set("n", "<C-n>", "<CMD>Neotree<CR>", { silent = true })

-- COC
-- when normal mode
-- double space
-- vim.keymap.set('n', '<space><space>', '<Cmd>CocList<CR>', { silent = true })
-- space + hwover = Hover
-- vim.keymap.set('n', '<space>h', '<Cmd>call CocAction("doHover")<CR>', { silent = true })
-- space + df = Definition
-- vim.keymap.set('n', '<space>df', '<Plug>(coc-definition)', { silent = true })
-- space + rf = References
-- vim.keymap.set('n', '<space>rf', '<Plug>(coc-references)', { silent = true })
-- LSP Rename (Global mapping to ensure availability)
vim.keymap.set("n", "<space>rn", function()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients > 0 then
    vim.lsp.buf.rename()
  else
    vim.notify("No LSP client attached to current buffer", vim.log.levels.WARN)
  end
end, { noremap = true, silent = true, desc = "LSP Rename" })

-- COC Rename (Legacy - commented out)
-- vim.keymap.set('n', '<space>rn', '<Plug>(coc-rename)', { silent = true })
