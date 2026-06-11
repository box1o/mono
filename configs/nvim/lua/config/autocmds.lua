local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

local function clear_error_hl()
	vim.api.nvim_set_hl(0, "@error", {})
	vim.api.nvim_set_hl(0, "@none", {})
end
clear_error_hl()
autocmd("ColorScheme", { pattern = "*", callback = clear_error_hl })

autocmd("TextYankPost", {
	group = augroup("YankHighlight", { clear = true }),
	callback = function() vim.hl.on_yank() end,
})

autocmd("VimResized", {
	group = augroup("ResizeWindows", { clear = true }),
	callback = function() vim.cmd("tabdo wincmd =") end,
})

autocmd("BufWritePre", {
	group = augroup("FormatOnSave", { clear = true }),
	callback = function(args)
		if not vim.g.autoformat then return end
		local ok, conform = pcall(require, "conform")
		if not ok then return end
		conform.format({ bufnr = args.buf, timeout_ms = 500, lsp_format = "fallback" })
	end,
})
