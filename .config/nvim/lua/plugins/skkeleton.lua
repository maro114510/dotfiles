-- https://github.com/vim-skk/skkeleton.git

return {
	--[[ {
		"vim-skk/skkeleton",

		dependencies = 'vim-denops/denops.vim',

		event = { "VeryLazy", "InsertEnter", "CmdlineEnter", "CmdwinEnter" },
		ft = { "markdown", "vim", "tex", "plaintex", "mail", "gitcommit" },
		config = function()
			vim.fn["skkeleton#config"]({
				globalDictionaries = {"~/.skk/SKK-JISYO.L"},
				userDictionary = "~/.skk/USER-JISYO",
				eggLikeNewline = true, -- 変換モードで改行したときに、確定だけ行う(改行しない)
			})
			vim.fn["skkeleton#register_kanatable"]("rom", {
				jj = "escape",
				ll = "disable",
				la = { "ぁ" },
				li = { "ぃ" },
				lu = { "ぅ" },
				le = { "ぇ" },
				lo = { "ぉ" },
				lya = { "ゃ" },
				lyu = { "ゅ" },
				lyo = { "ょ" },
				ltu = { "っ" },
				ltsu = { "っ" },
			})
		end,
	}, ]]
	--- Indicator
	--[[ {

		"delphinus/skkeleton_indicator.nvim",
		event = { "VeryLazy", "InsertEnter", "CmdlineEnter", "CmdwinEnter" },
		ft = { "markdown", "vim", "tex", "plaintex", "mail", "gitcommit" },
		dependencies = { "vim-skk/skkeleton" },
		opts = { fadeOutMs = 0 },
	}, ]]
}
