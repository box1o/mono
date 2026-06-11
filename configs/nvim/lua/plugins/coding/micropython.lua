return {
	{
		"jim-at-jibba/micropython.nvim",
		ft = "python",
		dependencies = { "folke/snacks.nvim" },
		keys = {
			{ "<leader>mr", function() require("micropython_nvim").run() end, desc = "MicroPython run buffer" },
			{ "<leader>mu", "<cmd>MPUpload<cr>",      desc = "MicroPython upload buffer" },
			{ "<leader>mU", "<cmd>MPUploadAll<cr>",   desc = "MicroPython upload project" },
			{ "<leader>mm", "<cmd>MPRunMain<cr>",     desc = "MicroPython run main.py" },
			{ "<leader>ms", "<cmd>MPSync<cr>",        desc = "MicroPython sync mount" },
			{ "<leader>mp", "<cmd>MPSetPort<cr>",     desc = "MicroPython set port" },
			{ "<leader>mb", "<cmd>MPSetBaud<cr>",     desc = "MicroPython set baud" },
			{ "<leader>md", "<cmd>MPListDevices<cr>", desc = "MicroPython list devices" },
			{ "<leader>mi", "<cmd>MPInit<cr>",        desc = "MicroPython init project" },
			{ "<leader>mI", "<cmd>MPInstall<cr>",     desc = "MicroPython install deps" },
			{ "<leader>me", "<cmd>MPRepl<cr>",        desc = "MicroPython REPL" },
			{ "<leader>ml", "<cmd>MPListFiles<cr>",   desc = "MicroPython list device files" },
			{ "<leader>mR", "<cmd>MPReset<cr>",       desc = "MicroPython soft reset" },
		},
	},
}
