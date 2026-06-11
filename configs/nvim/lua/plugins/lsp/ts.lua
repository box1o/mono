return {
	{
		"pmizio/typescript-tools.nvim",
		dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
		opts = {},
	},

	{
		"alvan/vim-closetag",
		ft = {
			"html", "xml",
			"javascript", "javascriptreact",
			"typescript", "typescriptreact",
			"vue", "svelte",
		},
		init = function()
			vim.g.closetag_filenames = "*.html,*.xhtml,*.jsx,*.tsx,*.vue,*.svelte"
			vim.g.closetag_filetypes =
				"html,xhtml,javascript,javascriptreact,typescript,typescriptreact,vue,svelte"
			vim.g.closetag_xhtml_filenames = "*.xhtml,*.jsx,*.tsx"
			vim.g.closetag_xhtml_filetypes = "xhtml,jsx,javascriptreact,tsx,typescriptreact"
			vim.g.closetag_emptyTags_caseSensitive = 1
			vim.g.closetag_shortcut = ">"
		end,
		config = function()
			local web_fts = {
				html = true, xml = true,
				javascript = true, javascriptreact = true,
				typescript = true, typescriptreact = true,
				vue = true, svelte = true,
			}

			vim.api.nvim_create_autocmd("CompleteDone", {
				group = vim.api.nvim_create_augroup("closetag_on_complete", { clear = true }),
				callback = function()
					if not web_fts[vim.bo.filetype] then return end
					local col = vim.api.nvim_win_get_cursor(0)[2]
					local before = vim.api.nvim_get_current_line():sub(1, col)
					if before:match("<%a[%a%d%-%.]*$") then
						vim.fn.feedkeys(">", "m")
					end
				end,
			})
		end,
	},
}
