local lsp_util = vim.lsp and vim.lsp.util
if lsp_util and type(lsp_util.show_document) == "function" then
	lsp_util.jump_to_location = function(location, offset_encoding, reuse_win)
		return lsp_util.show_document(location, offset_encoding, {
			focus = true,
			reuse_win = reuse_win ~= false,
		})
	end
end

local _orig_make_position_params = vim.lsp.util.make_position_params
vim.lsp.util.make_position_params = function(window, offset_encoding)
	window = window or 0
	if not offset_encoding then
		local buf = vim.api.nvim_win_get_buf(window)
		local clients = vim.lsp.get_clients({ bufnr = buf })
		if #clients > 0 then
			offset_encoding = clients[1].offset_encoding
		end
	end
	return _orig_make_position_params(window, offset_encoding)
end
