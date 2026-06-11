local map = vim.keymap.set
local cpp_pairs = require("config.cpp_pairs")

map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save file" })
map("n", "<leader>q", function()
	pcall(vim.cmd, "w")
	vim.cmd("q!")
end, { desc = "Save and quit" })
map({ "n", "i", "v" }, "<C-q>", "<cmd>silent! qa!<cr>", { desc = "Force quit all" })
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })
map("n", "U", "<C-r>", { desc = "Redo" })

map("n", "S", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Replace word under cursor (whole buffer)" })
map("v", "S", [[:s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Replace word under cursor (selection only)" })

map("n", "<A-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
map("n", "<A-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
map("n", "<A-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
map("n", "<A-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
map("t", "<esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
map("t", "<C-h>", "<Cmd>wincmd h<CR>", { desc = "Terminal: move to left window" })
map("t", "<C-j>", "<Cmd>wincmd j<CR>", { desc = "Terminal: move to bottom window" })
map("t", "<C-k>", "<Cmd>wincmd k<CR>", { desc = "Terminal: move to top window" })
map("t", "<C-l>", "<Cmd>wincmd l<CR>", { desc = "Terminal: move to right window" })

map("n", "gl", vim.diagnostic.open_float, { desc = "Open diagnostics in float" })
map("n", "<leader>cf", function()
	require("conform").format({ lsp_format = "fallback" })
end, { desc = "Format current file" })
map("n", "<leader>cp", cpp_pairs.prompt_create_pair, { desc = "Create C++ pair" })
map("n", "<leader>ca", cpp_pairs.switch, { desc = "Open paired C++ file" })

for key, cmd in pairs({
	["<C-u>"] = "<C-u>zz", ["<C-d>"] = "<C-d>zz",
	["{"] = "{zz", ["}"] = "}zz",
	["N"] = "Nzz", ["n"] = "nzz",
	["G"] = "Gzz", ["gg"] = "ggzz",
	["<C-i>"] = "<C-i>zz", ["<C-o>"] = "<C-o>zz",
	["%"] = "%zz", ["*"] = "*zz", ["#"] = "#zz",
}) do
	map("n", key, cmd, { desc = "Centered " .. key })
end

vim.api.nvim_create_user_command("CopyLspErrors", function()
	vim.diagnostic.setqflist({ open = false })
	vim.cmd("copen")
end, { desc = "Copy LSP errors to quickfix" })

vim.api.nvim_create_user_command("CopyWorkspaceLspErrors", function()
	vim.diagnostic.setqflist({ open = false, scope = "workspace" })
	vim.cmd("copen")
end, { desc = "Copy all workspace LSP errors" })

map("n", "<leader>le", ":CopyLspErrors<CR>", { desc = "Copy LSP errors" })
map("n", "<leader>lE", ":CopyWorkspaceLspErrors<CR>", { desc = "Copy workspace LSP errors" })
map("n", "<leader>ip", "<cmd>ImagePreview<CR>", { desc = "Image preview" })
map("n", "<leader>ic", "<cmd>ImageClear<CR>", { desc = "Clear image preview" })
