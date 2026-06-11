return {
	{
		"stevearc/oil.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		keys = {
			{ "<leader>e", function() require("oil").toggle_float() end, desc = "File explorer (float)" },
		},
		opts = {
			default_file_explorer = true,
			columns = { "icon" },
			float = { padding = 2 },
			keymaps = {
				["<C-h>"] = false,
				["<C-l>"] = false,
				["<leader>cp"] = {
					callback = function()
						require("config.cpp_pairs").prompt_create_pair()
					end,
					desc = "Create C++ pair",
					mode = "n",
				},
			},
			use_default_keymaps = true,
			view_options = { show_hidden = true },
		},
	},

	{
		"nvim-tree/nvim-tree.lua",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		cmd = { "NvimTreeToggle", "NvimTreeFocus" },
		keys = {
			{ "<leader>t", "<cmd>NvimTreeToggle<CR>", desc = "Toggle file tree" },
		},
		config = function()
			require("nvim-tree").setup({
				view = { width = 45, side = "right" },
				renderer = { group_empty = true },
				filters = { dotfiles = false },
				git = { enable = true },
			})
		end,
	},
}
