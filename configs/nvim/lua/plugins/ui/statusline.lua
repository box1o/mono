-- Lualine configuration - enhanced statusline
return {
	{
		"nvim-lualine/lualine.nvim",
		dependencies = {
			"nvim-tree/nvim-web-devicons",
			"ThePrimeagen/harpoon",
		},
		priority = 900, -- Load after colorscheme
		config = function()
			local function micropython_component()
				local ok, micropython = pcall(require, "micropython_nvim")
				if not ok or type(micropython.exists) ~= "function" or not micropython.exists() then
					return ""
				end

				return micropython.statusline()
			end

			-- Harpoon integration function
			local function harpoon_component()
				local harpoon_mark = require("harpoon.mark")
				local total_marks = harpoon_mark.get_length()

				if total_marks == 0 then
					return ""
				end

				local current_mark = "—"
				local mark_idx = harpoon_mark.get_current_index()

				if mark_idx ~= nil then
					current_mark = tostring(mark_idx)
				end

				return string.format("󱡅 %s/%d", current_mark, total_marks)
			end

			-- Git branch formatter - shortens long branch names
			local function format_branch(branch)
				if not branch or branch == "" then
					return ""
				end

				-- Handle common patterns like feature/abc-123
				local feature, ticket = string.match(branch, "^(%w+)/(.+)%-(%d+)")
				if feature and ticket then
					return feature:sub(1, 1) .. "/" .. ticket
				end

				-- Check if branch has a slash
				local parts = vim.split(branch, "/")
				if #parts > 1 then
					-- Take first char of first part + second part
					return parts[1]:sub(1, 1) .. "/" .. parts[2]
				end

				-- If branch name is longer than 20 chars, truncate it
				if #branch > 20 then
					return branch:sub(1, 17) .. "..."
				end

				return branch
			end

			-- LSP progress component
			local function lsp_progress()
				-- Get current LSP client and check if there's progress
				local lsp = vim.lsp.util.get_progress_messages()[1]
				if lsp then
					local name = lsp.name or ""
					local msg = lsp.message or ""
					local percentage = lsp.percentage or 0

					-- Spinner characters for animation
					local spinners = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
					local frame = math.floor(os.clock() * 10) % #spinners + 1

					return string.format("%s %s %s (%d%%)", spinners[frame], name, msg, percentage)
				end

				return ""
			end

			-- File size formatter
			local function file_size()
				local file = vim.fn.expand("%:p")
				if file == nil or file == "" then
					return ""
				end

				local size = vim.fn.getfsize(file)
				if size <= 0 then
					return ""
				end

				local suffixes = { "B", "KB", "MB", "GB" }
				local i = 1
				while size > 1024 and i < #suffixes do
					size = size / 1024
					i = i + 1
				end

				return string.format("%.1f%s", size, suffixes[i])
			end

			-- Mode display with custom highlight colors
			local modes = {
				["n"] = { name = "NORMAL", color = "LualineNormalMode" },
				["no"] = { name = "O-PENDING", color = "LualineNormalMode" },
				["nov"] = { name = "O-PENDING", color = "LualineNormalMode" },
				["noV"] = { name = "O-PENDING", color = "LualineNormalMode" },
				["no\22"] = { name = "O-PENDING", color = "LualineNormalMode" },
				["niI"] = { name = "NORMAL", color = "LualineNormalMode" },
				["niR"] = { name = "NORMAL", color = "LualineNormalMode" },
				["niV"] = { name = "NORMAL", color = "LualineNormalMode" },
				["i"] = { name = "INSERT", color = "LualineInsertMode" },
				["ic"] = { name = "INSERT", color = "LualineInsertMode" },
				["ix"] = { name = "INSERT", color = "LualineInsertMode" },
				["t"] = { name = "TERMINAL", color = "LualineTerminalMode" },
				["nt"] = { name = "TERMINAL", color = "LualineTerminalMode" },
				["v"] = { name = "VISUAL", color = "LualineVisualMode" },
				["vs"] = { name = "VISUAL", color = "LualineVisualMode" },
				["V"] = { name = "V-LINE", color = "LualineVisualMode" },
				["Vs"] = { name = "V-LINE", color = "LualineVisualMode" },
				["\22"] = { name = "V-BLOCK", color = "LualineVisualMode" },
				["\22s"] = { name = "V-BLOCK", color = "LualineVisualMode" },
				["R"] = { name = "REPLACE", color = "LualineReplaceMode" },
				["Rc"] = { name = "REPLACE", color = "LualineReplaceMode" },
				["Rx"] = { name = "REPLACE", color = "LualineReplaceMode" },
				["Rv"] = { name = "V-REPLACE", color = "LualineReplaceMode" },
				["s"] = { name = "SELECT", color = "LualineSelectMode" },
				["S"] = { name = "S-LINE", color = "LualineSelectMode" },
				["\19"] = { name = "S-BLOCK", color = "LualineSelectMode" },
				["c"] = { name = "COMMAND", color = "LualineCommandMode" },
				["cv"] = { name = "COMMAND", color = "LualineCommandMode" },
				["ce"] = { name = "COMMAND", color = "LualineCommandMode" },
				["r"] = { name = "PROMPT", color = "LualineConfirmMode" },
				["rm"] = { name = "PROMPT", color = "LualineConfirmMode" },
				["r?"] = { name = "CONFIRM", color = "LualineConfirmMode" },
			}

			-- Configure lualine with all components
			require("lualine").setup({
				options = {
					theme = "auto",
					globalstatus = true,
					disabled_filetypes = { statusline = { "dashboard", "alpha" } },
					section_separators = { left = "", right = "" },
					component_separators = { left = "│", right = "│" },
				},
				sections = {
					lualine_a = {
						{
							"mode",
							fmt = function(str)
								local mode = vim.api.nvim_get_mode().mode
								return modes[mode] and modes[mode].name or str
							end,
							padding = { left = 1, right = 1 },
						},
					},
					lualine_b = {
						{
							"branch",
							fmt = format_branch,
							icon = "󰘬",
							padding = { left = 1, right = 1 },
						},
						harpoon_component,
						{
							"diff",
							symbols = { added = " ", modified = " ", removed = " " },
							padding = { left = 1, right = 1 },
						},
						{
							"diagnostics",
							sources = { "nvim_diagnostic" },
							symbols = { error = " ", warn = " ", info = " ", hint = " " },
							padding = { left = 1, right = 1 },
						},
						{
							micropython_component,
							padding = { left = 1, right = 1 },
						},
					},
					lualine_c = {
						{
							"filetype",
							icon_only = true,
							padding = { left = 1, right = 0 },
						},
						{
							"filename",
							path = 1,
							symbols = {
								modified = "●",
								readonly = "",
								unnamed = "[No Name]",
								newfile = "[New]",
							},
							padding = { left = 1, right = 1 },
						},
						{
							lsp_progress,
							padding = { left = 0, right = 1 },
						},
					},
					lualine_x = {
						{
							file_size,
							padding = { left = 1, right = 1 },
						},
						{
							"encoding",
							padding = { left = 1, right = 1 },
						},
						{
							"fileformat",
							symbols = {
								unix = "󰌽 ", -- LF
								dos = "󰘿 ", -- CRLF
								mac = "󰘵 ", -- CR
							},
							padding = { left = 1, right = 1 },
						},
					},
					lualine_y = {
						{
							"filetype",
							padding = { left = 1, right = 1 },
						},
					},
					lualine_z = {
						{
							"location",
							padding = { left = 1, right = 1 },
						},
						{
							"progress",
							padding = { left = 1, right = 1 },
						},
					},
				},
				inactive_sections = {
					lualine_a = {},
					lualine_b = {},
					lualine_c = {
						{
							"filename",
							path = 1,
						},
					},
					lualine_x = { "location" },
					lualine_y = {},
					lualine_z = {},
				},
				extensions = {
					"oil",
					"toggleterm",
					"lazy",
					"trouble",
					"nvim-tree",
					"quickfix",
					"fugitive",
				},
			})
		end,
	},
}
