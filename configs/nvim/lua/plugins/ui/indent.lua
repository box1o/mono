return {
	{
		"lukas-reineke/indent-blankline.nvim",
		main = "ibl",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			local function set_hl()
				vim.api.nvim_set_hl(0, "IblScope", { link = "Function" })
			end
			set_hl()
			vim.api.nvim_create_autocmd("ColorScheme", { callback = set_hl })

			require("ibl").setup({
				indent = { char = "│" },
				scope = { enabled = true, show_start = false, show_end = false },
				exclude = {
					filetypes = {
						"help", "alpha", "dashboard", "lazy", "mason",
						"notify", "oil", "NvimTree", "toggleterm",
					},
				},
			})
		end,
	},
}
