-- Compatibility shim for plugins expecting old nvim-treesitter.configs APIs.
-- If a real configs module exists, use it; otherwise expose minimal fallbacks.

local this = debug.getinfo(1, "S").source:sub(2)
for _, path in ipairs(vim.api.nvim_get_runtime_file("lua/nvim-treesitter/configs.lua", true)) do
	if path ~= this then
		local ok, mod = pcall(dofile, path)
		if ok and type(mod) == "table" then
			return mod
		end
	end
end

local M = {}

function M.setup(_)
	-- no-op for new nvim-treesitter versions without legacy module
end

function M.is_enabled(_, _, _)
	-- Signal "disabled" so callers fall back to regex highlighting.
	return false
end

function M.get_module(_)
	return {
		additional_vim_regex_highlighting = false,
	}
end

return M
