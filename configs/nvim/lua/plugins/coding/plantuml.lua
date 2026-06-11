return {
	{
		"aklt/plantuml-syntax",
		ft = { "plantuml" },
	},
	{
		"tyru/open-browser.vim",
		lazy = true,
	},
	{
		"weirongxu/plantuml-previewer.vim",
		ft = { "plantuml" },
		cmd = { "PlantumlOpen", "PlantumlStart", "PlantumlStop", "PlantumlSave" },
		dependencies = {
			"aklt/plantuml-syntax",
			"tyru/open-browser.vim",
		},
		init = function()
			vim.g["plantuml_previewer#file_pattern"] = "*.pu,*.uml,*.plantuml,*.puml,*.iuml"
			vim.g["plantuml_previewer#save_format"] = "svg"

			vim.api.nvim_create_autocmd("FileType", {
				pattern = "plantuml",
				callback = function(event)
					local opts = { buffer = event.buf, silent = true }
					vim.keymap.set("n", "<leader>uo", "<cmd>PlantumlOpen<CR>", vim.tbl_extend("force", opts, {
						desc = "PlantUML open preview",
					}))
					vim.keymap.set("n", "<leader>us", "<cmd>PlantumlSave<CR>", vim.tbl_extend("force", opts, {
						desc = "PlantUML save SVG",
					}))
					vim.keymap.set("n", "<leader>ux", "<cmd>PlantumlStop<CR>", vim.tbl_extend("force", opts, {
						desc = "PlantUML stop preview",
					}))
				end,
			})
		end,
	},
}
