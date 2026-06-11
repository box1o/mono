return {
	{
		"folke/noice.nvim",
		event = "VeryLazy",
		dependencies = {
			"MunifTanjim/nui.nvim",
			"rcarriga/nvim-notify",
		},
		opts = {
			lsp = {
				override = {
					["vim.lsp.util.convert_input_to_markdown_lines"] = true,
					["vim.lsp.util.stylize_markdown"] = true,
					["cmp.entry.get_documentation"] = true,
				},
			},
			presets = {
				bottom_search = true,
				command_palette = true,
				long_message_to_split = true,
				inc_rename = false,
				lsp_doc_border = false,
			},
			routes = {
				{ filter = { event = "msg_show", find = "require%('lspconfig'%)" },       opts = { skip = true } },
				{ filter = { event = "msg_show", find = "No information available" },      opts = { skip = true } },
				{ filter = { event = "msg_show", find = "null%-ls.*timed out" },           opts = { skip = true } },
				{ filter = { event = "msg_show", find = "E37:" },                          opts = { skip = true } },
				{ filter = { event = "msg_show", find = "E32:" },                          opts = { skip = true } },
				{ filter = { event = "msg_show", find = "E162:" },                         opts = { skip = true } },
				{ filter = { event = "msg_show", find = "No write since last change" },    opts = { skip = true } },
				{ filter = { event = "msg_show", find = "No file name" },                  opts = { skip = true } },
				{ filter = { event = "msg_show", find = "E382:" },                         opts = { skip = true } },
				{ filter = { event = "msg_show", find = "E45:" },                          opts = { skip = true } },
				{ filter = { event = "msg_show", find = "client%.request is deprecated" }, opts = { skip = true } },
				{ filter = { event = "msg_show", find = "vim%.deprecated" },               opts = { skip = true } },
			},
		},
	},
}
