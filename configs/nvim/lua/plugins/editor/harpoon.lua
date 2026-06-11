return {
	"ThePrimeagen/harpoon",
	branch = "harpoon2",
	dependencies = { "nvim-lua/plenary.nvim" },
	config = function()
		local harpoon = require("harpoon")
		harpoon:setup()

		vim.keymap.set("n", "<leader>ha", function() harpoon:list():add() end, { desc = "Harpoon: Add file" })
		vim.keymap.set("n", "<leader>ho", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, { desc = "Harpoon: Toggle menu" })

		for i = 1, 9 do
			vim.keymap.set("n", "<leader>" .. i, function() harpoon:list():select(i) end, { desc = "Harpoon: File " .. i })
		end
	end,
}
