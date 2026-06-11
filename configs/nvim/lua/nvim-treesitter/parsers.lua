-- Compatibility shim for plugins expecting old nvim-treesitter parser APIs.
-- Delegates to the real module when available and backfills ft_to_lang.

local function ft_to_lang(ft)
	if type(ft) ~= "string" or ft == "" then
		return ft
	end

	local ts_lang = vim.treesitter and vim.treesitter.language
	if ts_lang and type(ts_lang.get_lang) == "function" then
		return ts_lang.get_lang(ft) or ft
	end

	return ft
end

local this = debug.getinfo(1, "S").source:sub(2)
for _, path in ipairs(vim.api.nvim_get_runtime_file("lua/nvim-treesitter/parsers.lua", true)) do
	if path ~= this then
		local ok, mod = pcall(dofile, path)
		if ok and type(mod) == "table" then
			if type(mod.ft_to_lang) ~= "function" then
				mod.ft_to_lang = ft_to_lang
			end
			return mod
		end
	end
end

return {
	ft_to_lang = ft_to_lang,
	get_parser = vim.treesitter.get_parser,
}
