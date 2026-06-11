return {
	{
		"nvim-telescope/telescope.nvim",
		event = "VimEnter",
		dependencies = {
			"nvim-lua/plenary.nvim",
			{
				"nvim-telescope/telescope-fzf-native.nvim",
				build = "make",
				cond = function() return vim.fn.executable("make") == 1 end,
			},
			{ "nvim-telescope/telescope-ui-select.nvim" },
			{ "nvim-tree/nvim-web-devicons", enabled = vim.g.have_nerd_font },
		},
		config = function()
			require("telescope").setup({
				extensions = {
					["ui-select"] = { require("telescope.themes").get_dropdown() },
				},
			})

			pcall(require("telescope").load_extension, "fzf")
			pcall(require("telescope").load_extension, "ui-select")

			local b = require("telescope.builtin")
			local map = vim.keymap.set

			map("n", "<leader>sh", b.help_tags,    { desc = "Search help" })
			map("n", "<leader>sk", b.keymaps,       { desc = "Search keymaps" })
			map("n", "<leader>sf", b.find_files,    { desc = "Search files" })
			map("n", "<leader>ss", b.builtin,       { desc = "Search telescope" })
			map("n", "<leader>sw", b.grep_string,   { desc = "Search current word" })
			map("n", "<leader>sg", b.live_grep,     { desc = "Search by grep" })
			map("n", "<leader>sd", b.diagnostics,   { desc = "Search diagnostics" })
			map("n", "<leader>sr", b.resume,        { desc = "Search resume" })
			map("n", "<leader>s.", b.oldfiles,      { desc = "Search recent files" })
			map("n", "<leader><leader>", b.buffers, { desc = "Find buffers" })

			map("n", "<leader>/", function()
				b.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
					winblend = 10, previewer = false,
				}))
			end, { desc = "Fuzzy search buffer" })

			map("n", "<leader>s/", function()
				b.live_grep({ grep_open_files = true, prompt_title = "Live Grep in Open Files" })
			end, { desc = "Search in open files" })

			map("n", "<leader>sn", function()
				b.find_files({ cwd = vim.fn.stdpath("config") })
			end, { desc = "Search nvim config" })
		end,
	},
}
