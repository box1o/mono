vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.smarttab = true
vim.opt.smartindent = true
vim.opt.autoindent = true
vim.opt.breakindent = true

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.numberwidth = 2

vim.opt.foldcolumn = "0"
vim.opt.signcolumn = "yes"

vim.opt.cursorline = true
vim.opt.showmode = false
vim.opt.scrolloff = 8
vim.opt.mouse = "a"
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.termguicolors = true
vim.opt.wrap = false

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = true
vim.opt.hlsearch = true

vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

vim.opt.undofile = true
vim.opt.clipboard = "unnamed,unnamedplus"
vim.opt.updatetime = 250
vim.opt.completeopt = { "menu", "menuone", "noselect" }

vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99
vim.opt.foldenable = true

vim.g.have_nerd_font = true
vim.g.autoformat = false

vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

vim.o.title = false
vim.o.showtabline = 0
vim.o.laststatus = 0
vim.o.cmdheight = 0

vim.api.nvim_create_autocmd("ColorScheme", {
	pattern = "*",
	callback = function()
		vim.cmd("highlight clear LineNr")
		vim.cmd("highlight clear CursorLineNr")
		vim.cmd("highlight clear SignColumn")
	end,
})
