return {
	{
		"lewis6991/gitsigns.nvim",
		opts = {
			signs = {
				add = { text = "+" },
				change = { text = "~" },
				delete = { text = "_" },
				topdelete = { text = "‾" },
				changedelete = { text = "~" },
			},
			on_attach = function(bufnr)
				local gs = package.loaded.gitsigns
				local map = function(mode, l, r, desc)
					vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
				end

				map("n", "]h", gs.next_hunk, "Next hunk")
				map("n", "[h", gs.prev_hunk, "Prev hunk")
				map({ "n", "v" }, "<leader>Gs", gs.stage_hunk, "Stage hunk")
				map({ "n", "v" }, "<leader>Gr", gs.reset_hunk, "Reset hunk")
				map("n", "<leader>GS", gs.stage_buffer, "Stage buffer")
				map("n", "<leader>GR", gs.reset_buffer, "Reset buffer")
				map("n", "<leader>Gu", gs.undo_stage_hunk, "Undo stage hunk")
				map("n", "<leader>Gd", gs.diffthis, "Diff this")
				map("n", "<leader>GD", function() gs.diffthis("~") end, "Diff against last commit")
				map("n", "<leader>Gb", function() gs.blame_line({ full = true }) end, "Blame line")
				map("n", "<leader>GB", gs.toggle_current_line_blame, "Toggle blame")
				map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "Select hunk")
			end,
		},
	},

	{
		"kdheepak/lazygit.nvim",
		lazy = true,
		dependencies = { "nvim-lua/plenary.nvim" },
		cmd = { "LazyGit", "LazyGitConfig", "LazyGitCurrentFile", "LazyGitFilter", "LazyGitFilterCurrentFile" },
		keys = {
			{ "<leader>Gz", "<cmd>LazyGit<cr>", desc = "LazyGit" },
		},
		config = function()
			vim.g.lazygit_floating_window_winblend = 0
			vim.g.lazygit_floating_window_scaling_factor = 0.9
			vim.g.lazygit_floating_window_border_chars = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
			vim.g.lazygit_use_neovim_remote = 1
		end,
	},

	{
		"sindrets/diffview.nvim",
		cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory", "DiffviewToggleFiles" },
		keys = {
			{ "<leader>Gv", "<cmd>DiffviewOpen<cr>", desc = "Diff view (index)" },
			{ "<leader>GV", "<cmd>DiffviewFileHistory %<cr>", desc = "File history" },
		},
	},

	{
		"NeogitOrg/neogit",
		lazy = true,
		dependencies = {
			"nvim-lua/plenary.nvim",
			"sindrets/diffview.nvim",
			"nvim-telescope/telescope.nvim",
		},
		cmd = "Neogit",
		keys = {
			{ "<leader>Gg", "<cmd>Neogit<cr>", desc = "Neogit status" },
			{ "<leader>Gc", "<cmd>Neogit commit<cr>", desc = "Neogit commit" },
			{ "<leader>Gl", "<cmd>Neogit log<cr>", desc = "Neogit log" },
			{ "<leader>Gp", "<cmd>Neogit push<cr>", desc = "Neogit push" },
			{ "<leader>Gf", "<cmd>Neogit fetch<cr>", desc = "Neogit fetch" },
		},
		opts = {
			integrations = { diffview = true, telescope = true },
			kind = "auto",
			signs = {
				hunk = { "", "" },
				item = { ">", "v" },
				section = { ">", "v" },
			},
			graph_style = "unicode",
		},
	},
}
