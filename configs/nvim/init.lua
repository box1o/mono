vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.have_nerd_font = true

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		error("Error cloning lazy.nvim:\n" .. out)
	end
end
vim.opt.rtp:prepend(lazypath)

require("config.keymaps")
require("config.autocmds")
require("config.options")
require("config.filetypes")
require("config.compat")
require("config.cpp_pairs").setup()

require("lazy").setup({
	{ import = "plugins" },
	{ import = "plugins.ui" },
	{ import = "plugins.editor" },
	{ import = "plugins.coding" },
	{ import = "plugins.lsp" },
}, {
	ui = {
		icons = vim.g.have_nerd_font and {} or {
			cmd = "⌘", config = "🛠", event = "📅", ft = "📂",
			init = "⚙", keys = "🗝", plugin = "🔌", runtime = "💻",
			require = "🌙", source = "📄", start = "🚀", task = "📌", lazy = "💤 ",
		},
	},
})
