-- https://github.com/MattesGroeger/vim-bookmarks.git

return {
  'MattesGroeger/vim-bookmarks',

  event = {
    'BufRead',
    'BufNewFile',
  },

  -- Keymap for vim-bookmarks
  -- mm - toggle vim-bookmarks
  -- mn - next vim-bookmarks
  -- mp - previous vim-bookmarks
  -- ma - annotate vim-bookmarks
}
