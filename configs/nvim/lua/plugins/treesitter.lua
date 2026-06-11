return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			require("nvim-treesitter.configs").setup({
				ensure_installed = {
					"c", "lua", "vim", "vimdoc", "query",
					"elixir", "heex",
					"javascript", "typescript", "tsx", "html", "css",
					"cpp", "rust", "go", "python",
					"json", "yaml", "toml",
					"java", "kotlin", "ruby", "php",
					"bash", "sql", "cmake", "make",
					"graphql", "regex", "terraform", "prisma",
					"zig", "dart", "hcl", "glsl",
					"diff", "markdown", "markdown_inline", "luadoc",
				},
				highlight = { enable = true },
				indent = { enable = true },
			})
		end,
	},
}
