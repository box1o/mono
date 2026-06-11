return {
	"mbbill/undotree",
	keys = {
		{
			"<leader>uu",
			function()
				vim.cmd.UndotreeToggle()
			end,
			desc = "UndoTree: Toggle panel",
		},
	},
	cmd = { "UndotreeToggle", "UndotreeShow", "UndotreeFocus" },
	config = function()
		-- Close panel automatically when buffer is wiped to avoid leftover windows
		vim.g.undotree_SetFocusWhenToggle = 1
	end,
}
