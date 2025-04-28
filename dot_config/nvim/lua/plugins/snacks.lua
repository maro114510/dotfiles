-- https://github.com/folke/snacks.nvim.git
-- Fuzzy Finder

-- ロゴを文字列で定義
local logo = [[
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
━━━━━━━━ ▄▄    ▄ ▄▄▄▄▄▄▄ ▄▄▄▄▄▄▄ ▄▄   ▄▄ ▄▄ ▄▄   ▄▄ ━━━━━━━━
━━━━━━━━█  █  █ █       █       █  █ █  █  █  █▄█  █━━━━━━━━
━━━━━━━━█   █▄█ █    ▄▄▄█   ▄   █  █▄█  █  █       █━━━━━━━━
━━━━━━━━█       █   █▄▄▄█  █ █  █       █  █       █━━━━━━━━
━━━━━━━━█  ▄    █    ▄▄▄█  █▄█  █       █  █       █━━━━━━━━
━━━━━━━━█ █ █   █   █▄▄▄█       ██     ██  █ ██▄██ █━━━━━━━━
━━━━━━━━█▄█  █▄▄█▄▄▄▄▄▄▄█▄▄▄▄▄▄▄█ █▄▄▄█ █▄▄█▄█   █▄█━━━━━━━━
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]
-- 表示に使う`tte`のサブコマンド（アニメーション指定）
local subcommands = {
  'middleout --center-movement-speed 0.8 --full-movement-speed 0.2',
  'slide --merge --movement-speed 0.8',
  'beams --beam-delay 5 --beam-row-speed-range 20-60 --beam-column-speed-range 8-12',
}
-- 候補のサブコマンドからランダムに1個を使用
math.randomseed(os.time())
local subcommand = subcommands[math.random(#subcommands)]
-- Neovimのjobで実行するコマンド
local cmd = {
  'sh',
  '-c',
  'echo '
  .. vim.fn.shellescape(vim.trim(logo))
  .. ' | tte --anchor-canvas s ' .. subcommand
  .. ' --final-gradient-direction diagonal'
}

return {
  "folke/snacks.nvim",

  priority = 1000,

  lazy = false,

  ---@type snacks.Config
  opts = {
    -- your configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below
    bigfile = { enabled = true, hidden = true },
    dashboard = {
      enabled = true,
      sections = {
        {
          section = "terminal",
          cmd = cmd,
          random = 10,
          pane = 1,
          padding = 0.6,
          height = 10,
          width = 60,
          gap = 1,
        },
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
      },
      pane_gap = 1.0,
    },
    explorer = {
      enabled = true,
      hidden = true,
    },
    indent = { enabled = true },
    input = { enabled = true },
    picker = {
      enabled = true,
      sources = {
        files = { hidden = true },
        explorer = { hidden = true },
      },
    },
    notifier = { enabled = false },
    quickfile = { enabled = true, hidden = true },
    scope = { enabled = true },
    scroll = { enabled = false },
    statuscolumn = { enabled = true },
    words = { enabled = true },
    toggle = { enabled = false },
  },

  keys = {
    -- Top Pickers & Explorer
    { "<leader><space>", function() Snacks.picker.smart() end, desc = "Smart Find Files" },
    { "<leader>,", function() Snacks.picker.buffers() end, desc = "Buffers" },
    { "<leader>/", function() Snacks.picker.grep() end, desc = "Grep" },
    { "<leader>:", function() Snacks.picker.command_history() end, desc = "Command History" },
    { "<leader>n", function() Snacks.picker.notifications() end, desc = "Notification History" },
    { "<leader>e", function() Snacks.explorer() end, desc = "File Explorer" },
    -- find
    { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
    { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Find Config File" },
    { "<leader>ff", function() Snacks.picker.files() end, desc = "Find Files" },
    { "<leader>fg", function() Snacks.picker.git_files() end, desc = "Find Git Files" },
    { "<leader>fp", function() Snacks.picker.projects() end, desc = "Projects" },
    { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent" },
    -- Grep
    { "<leader>sb", function() Snacks.picker.lines() end, desc = "Buffer Lines" },
    { "<leader>sg", function() Snacks.picker.grep() end, desc = "Grep" },
    -- search
    { "<leader>sa", function() Snacks.picker.autocmds() end, desc = "Autocmds" },
    { "<leader>sc", function() Snacks.picker.command_history() end, desc = "Command History" },
    -- Other
    { "<leader>z",  function() Snacks.zen() end, desc = "Toggle Zen Mode" },
    { "<leader>n",  function() Snacks.notifier.show_history() end, desc = "Notification History" },
    { "<leader>bd", function() Snacks.bufdelete() end, desc = "Delete Buffer" },
    { "<leader>cR", function() Snacks.rename.rename_file() end, desc = "Rename File" },
    { "<leader>gg", function() Snacks.lazygit() end, desc = "Lazygit" },
    { "<leader>un", function() Snacks.notifier.hide() end, desc = "Dismiss All Notifications" },
    { "<c-/>",      function() Snacks.terminal() end, desc = "Toggle Terminal" },
    { "<c-_>",      function() Snacks.terminal() end, desc = "which_key_ignore" },
    { "]]",         function() Snacks.words.jump(vim.v.count1) end, desc = "Next Reference", mode = { "n", "t" } },
    { "[[",         function() Snacks.words.jump(-vim.v.count1) end, desc = "Prev Reference", mode = { "n", "t" } },
    { "<leader>N", desc = "Neovim News",
      function()
      Snacks.win({
        file = vim.api.nvim_get_runtime_file("doc/news.txt", false)[1],
        width = 0.6,
        height = 0.6,
        wo = {
        spell = false,
        wrap = false,
        signcolumn = "yes",
        statuscolumn = " ",
        conceallevel = 3,
        },
      })
    end,
    }
  },

  init = function()
    -- Vimがスタートしたら、ロゴを表示する関数を呼び出す
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        -- ダッシュボードが表示されるまで少し待ってから実行
        vim.defer_fn(function()
          if vim.bo.filetype == "dashboard" then
            -- ロゴを描画（ダッシュボードの上に重なって表示される）
            display_logo(logo)
          end
        end, 100)
      end,
    })

    vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    callback = function()
      -- Setup some globals for debugging (lazy-loaded)
      _G.dd = function(...)
        Snacks.debug.inspect(...)
      end

      _G.bt = function()
        Snacks.debug.backtrace()
      end

      vim.print = _G.dd -- Override print to use snacks for `:=` command

      -- Create some toggle mappings
      Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
      Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
      Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
      Snacks.toggle.diagnostics():map("<leader>ud")
      Snacks.toggle.line_number():map("<leader>ul")
      Snacks.toggle.option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 }):map("<leader>uc")
      Snacks.toggle.treesitter():map("<leader>uT")
      Snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark Background" }):map("<leader>ub")
      Snacks.toggle.inlay_hints():map("<leader>uh")
      Snacks.toggle.indent():map("<leader>ug")
      Snacks.toggle.dim():map("<leader>uD")
      end,
    })
  end,
}
