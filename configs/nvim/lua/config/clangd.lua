local M = {}

function M.query_driver()
	return table.concat({
		"**/bin/clang",
		"**/bin/clang++",
		"**/bin/*clang++",
		"**/aarch64-linux-android*-clang++",
		"**/armv7a-linux-androideabi*-clang++",
		"**/x86_64-linux-android*-clang++",
		"**/i686-linux-android*-clang++",
	}, ",")
end

function M.server(capabilities)
	return {
		cmd = {
			"clangd",
			"--background-index",
			"--clang-tidy",
			"--header-insertion=never",
			"--query-driver=" .. M.query_driver(),
		},
		filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
		root_markers = { ".clangd", "compile_commands.json", "compile_flags.txt", ".git" },
		capabilities = capabilities,
	}
end

return M
