return {
	{
		"rcarriga/nvim-notify",
		event = "VeryLazy",
		opts = {
			background_colour = "#1F1F28",
			render = "compact",
			stages = "fade",
			timeout = 3000,
			max_height = function() return math.floor(vim.o.lines * 0.75) end,
			max_width = function() return math.floor(vim.o.columns * 0.75) end,
			on_open = function(win)
				vim.api.nvim_win_set_config(win, { border = "rounded" })
			end,
		},
		config = function(_, opts)
			require("notify").setup(opts)
			vim.cmd([[
				highlight NotifyERRORBorder guifg=#e82424
				highlight NotifyERRORIcon   guifg=#e82424
				highlight NotifyERRORTitle  guifg=#e82424
				highlight NotifyINFOBorder  guifg=#658594
				highlight NotifyINFOIcon    guifg=#658594
				highlight NotifyINFOTitle   guifg=#658594
				highlight NotifyWARNBorder  guifg=#ffa066
				highlight NotifyWARNIcon    guifg=#ffa066
				highlight NotifyWARNTitle   guifg=#ffa066
			]])
		end,
	},
}
