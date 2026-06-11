return {
	{
		"linux-cultist/venv-selector.nvim",
		ft = "python",
		dependencies = {
			"neovim/nvim-lspconfig",
			{ "nvim-telescope/telescope.nvim", branch = "0.1.x", dependencies = { "nvim-lua/plenary.nvim" } },
		},
		keys = { { ",v", "<cmd>VenvSelect<cr>" } },
		opts = {},
	},
}
