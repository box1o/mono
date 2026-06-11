local theme_file = vim.fn.stdpath("data") .. "/nvim_theme.txt"
local default_theme = "kanagawa-dragon"

local available_themes = {
	"kanagawa-dragon", "kanagawa-wave", "kanagawa-lotus",
	"catppuccin-mocha", "catppuccin-frappe", "catppuccin-macchiato", "catppuccin-latte",
	"gruvbox", "gruvbox-light",
	"rose-pine", "rose-pine-moon", "rose-pine-dawn",
	"oxocarbon",
	"minimal",
}

local light_themes = {
	["kanagawa-lotus"] = true, ["catppuccin-latte"] = true,
	["rose-pine-dawn"] = true, ["gruvbox-light"] = true,
}

local cs_map = { ["gruvbox-light"] = "gruvbox" }

local function save_theme(name)
	local f = io.open(theme_file, "w")
	if f then f:write(name); f:close() end
end

local function load_theme()
	local f = io.open(theme_file, "r")
	if f then
		local name = f:read("*l"); f:close()
		if name and name ~= "" then return name end
	end
	return default_theme
end

local function apply_theme(name)
	vim.o.background = light_themes[name] and "light" or "dark"
	local ok = pcall(vim.cmd, "colorscheme " .. (cs_map[name] or name))
	if not ok then
		vim.notify("Theme not found: " .. name, vim.log.levels.WARN)
		pcall(vim.cmd, "colorscheme " .. default_theme)
		return
	end
	save_theme(name)
end

local function preview(name)
	vim.o.background = light_themes[name] and "light" or "dark"
	pcall(vim.cmd, "colorscheme " .. (cs_map[name] or name))
end

local function pick_theme()
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf    = require("telescope.config").values
	local actions = require("telescope.actions")
	local state   = require("telescope.actions.state")
	local original = load_theme()

	local function apply_selected()
		vim.schedule(function()
			local sel = state.get_selected_entry()
			if sel then preview(sel[1]) end
		end)
	end

	pickers.new({}, {
		prompt_title = "Themes",
		finder = finders.new_table({ results = available_themes }),
		sorter = conf.generic_sorter({}),
		attach_mappings = function(prompt_bufnr, map)
			-- Fire on every up/down navigation
			actions.move_selection_next:enhance({ post = apply_selected })
			actions.move_selection_previous:enhance({ post = apply_selected })
			actions.move_selection_better:enhance({ post = apply_selected })
			actions.move_selection_worse:enhance({ post = apply_selected })

			actions.select_default:replace(function()
				local sel = state.get_selected_entry()
				actions.close(prompt_bufnr)
				if sel then apply_theme(sel[1]) end
			end)

			local cancel = function()
				actions.close(prompt_bufnr)
				apply_theme(original)
			end
			map("i", "<Esc>", cancel)
			map("n", "<Esc>", cancel)
			map("n", "q", cancel)
			return true
		end,
	}):find()
end

return {
	{
		"rebelot/kanagawa.nvim",
		priority = 1000,
		config = function()
			require("kanagawa").setup({
				compile = false,
				undercurl = true,
				commentStyle = { italic = true },
				keywordStyle = { italic = true },
				statementStyle = { bold = true },
				transparent = false,
				terminalColors = true,
				theme = "dragon",
				background = { dark = "dragon", light = "lotus" },
				colors = { theme = { all = { ui = { bg_gutter = "none" } } } },
				overrides = function(colors)
					local t = colors.theme
					return {
						TelescopeTitle         = { fg = t.ui.special, bold = true },
						TelescopePromptNormal  = { bg = t.ui.bg_p1 },
						TelescopePromptBorder  = { fg = t.ui.bg_p1, bg = t.ui.bg_p1 },
						TelescopeResultsNormal = { fg = t.ui.fg_dim, bg = t.ui.bg_m1 },
						TelescopeResultsBorder = { fg = t.ui.bg_m1, bg = t.ui.bg_m1 },
						TelescopePreviewNormal = { bg = t.ui.bg_dim },
						TelescopePreviewBorder = { bg = t.ui.bg_dim, fg = t.ui.bg_dim },
						NormalFloat  = { bg = t.ui.bg_m3 },
						FloatBorder  = { bg = t.ui.bg_m3, fg = t.ui.bg_m3 },
						FloatTitle   = { bg = t.ui.bg_m3 },
						Pmenu        = { fg = t.ui.shade0, bg = t.ui.bg_p1 },
						PmenuSel     = { fg = "NONE", bg = t.ui.bg_p2 },
						PmenuSbar    = { bg = t.ui.bg_m1 },
						PmenuThumb   = { bg = t.ui.bg_p2 },
					}
				end,
			})
			apply_theme(load_theme())
			vim.keymap.set("n", "<leader>ut", pick_theme, { desc = "Theme picker" })
		end,
	},

	{
		"catppuccin/nvim",
		name = "catppuccin",
		priority = 1000,
		opts = {
			flavour = "mocha",
			background = { light = "latte", dark = "mocha" },
			integrations = {
				telescope = { enabled = true },
				harpoon = true, mason = true, which_key = true,
				treesitter = true, noice = true, notify = true,
				mini = { enabled = true }, gitsigns = true, blink_cmp = true,
			},
		},
	},

	{
		"ellisonleao/gruvbox.nvim",
		priority = 1000,
		opts = { contrast = "hard" },
	},

	{
		"rose-pine/neovim",
		name = "rose-pine",
		priority = 1000,
		opts = { variant = "auto", dark_variant = "moon" },
	},

	{
		"nyoom-engineering/oxocarbon.nvim",
		priority = 1000,
	},

	{
		"Yazeed1s/minimal.nvim",
		priority = 1000,
	},
}
