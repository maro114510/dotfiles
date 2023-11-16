-- -番号表示
vim.opt.number = true
-- -エラー時の音を画面表示に
vim.opt.visualbell = true

-- -大文字無視
vim.opt.ignorecase = true
-- -大文字で検索したら区別をつける
vim.opt.smartcase = true
-- -検索が末尾までいったら先頭から検索
vim.opt.wrapscan = true

-- カーソル移動
-- - 行を跨いでの移動
vim.opt.whichwrap = 'b', 's', 'h', 'l', '<', '>', '[', ']'
-- - 削除時の対象
vim.opt.backspace = 'start', 'eol', 'indent'

-- クリップボード連携
vim.opt.clipboard:append({unnamedeplus = true})

-- マウス有効
vim.opt.mouse = 'a'
