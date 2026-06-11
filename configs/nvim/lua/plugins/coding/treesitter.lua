return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		config = function()
			local languages = {
				"c", "lua", "vim", "vimdoc", "query",
				"elixir", "heex",
				"javascript", "typescript", "tsx", "html", "css",
				"cpp", "rust", "go", "python",
				"json", "yaml", "toml",
				"java", "kotlin", "ruby", "php",
				"bash", "sql", "cmake", "make",
				"graphql", "regex", "terraform", "prisma",
				"zig", "dart", "hcl", "glsl", "wgsl",
				"diff", "markdown", "markdown_inline", "luadoc",
			}

			vim.api.nvim_create_user_command("TSInstallConfigured", function()
				require("nvim-treesitter").install(languages)
			end, { desc = "Install configured treesitter parsers" })

			vim.api.nvim_create_autocmd("FileType", {
				pattern = "wgsl",
				callback = function(event)
					for _, lang in ipairs({ "wgsl", "wgsl_bevy" }) do
						if pcall(vim.treesitter.language.add, lang) then
							pcall(vim.treesitter.start, event.buf, lang)
							return
						end
					end
					for _, lang in ipairs({ "wgsl", "wgsl_bevy" }) do
						pcall(require("nvim-treesitter").install, { lang })
					end
					pcall(vim.treesitter.start, event.buf, "wgsl")
				end,
			})

			vim.api.nvim_create_autocmd("FileType", {
				pattern = "*",
				callback = function() pcall(vim.treesitter.start) end,
			})
		end,
	},
}
