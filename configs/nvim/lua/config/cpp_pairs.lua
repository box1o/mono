local M = {}
local did_setup = false

local header_exts = { ".hpp", ".hh", ".h" }
local source_exts = { ".cpp", ".cc", ".cxx", ".c" }

local function normalize(path)
	return vim.fs.normalize(path):gsub("/+$", "")
end

local function stat(path)
	if not path or path == "" then
		return nil
	end

	return vim.uv.fs_stat(path)
end

local function is_dir(path)
	local info = stat(path)
	return info and info.type == "directory" or false
end

local function is_file(path)
	local info = stat(path)
	return info and info.type == "file" or false
end

local function dirname(path)
	return vim.fs.dirname(path)
end

local function current_path()
	local path = vim.api.nvim_buf_get_name(0)
	if path == "" then
		path = vim.uv.cwd()
	end

	path = path:gsub("^oil://", "")
	return normalize(path)
end

local function current_dir()
	if vim.bo.filetype == "oil" then
		local ok, oil = pcall(require, "oil")
		if ok and type(oil.get_current_dir) == "function" then
			local dir = oil.get_current_dir(0)
			if dir and dir ~= "" then
				return normalize(dir)
			end
		end
	end

	local path = current_path()
	if is_dir(path) then
		return path
	end

	return dirname(path)
end

local function module_root_from_path(path)
	if not path or path == "" then
		return nil
	end

	path = normalize(path)
	if not is_dir(path) then
		path = dirname(path)
	end

	while path and path ~= "" do
		if path:match("/modules/[^/]+$") then
			return path
		end

		local parent = dirname(path)
		if not parent or parent == path then
			return nil
		end

		path = parent
	end
end

local function get_module_root()
	return module_root_from_path(current_path()) or module_root_from_path(vim.uv.cwd())
end

local function relative_to(path, prefix)
	path = normalize(path)
	prefix = normalize(prefix)

	if path == prefix then
		return ""
	end

	local with_slash = prefix .. "/"
	if path:sub(1, #with_slash) == with_slash then
		return path:sub(#with_slash + 1)
	end
end

local function strip_extension(path)
	return path:gsub("%.[^./]+$", "")
end

local function detect_include_prefix(module_root)
	local include_dir = module_root .. "/include"
	if not is_dir(include_dir) then
		return nil
	end

	local matches = vim.fn.globpath(include_dir, "*", false, true)
	local dirs = {}
	for _, match in ipairs(matches) do
		match = normalize(match)
		if is_dir(match) then
			dirs[#dirs + 1] = match
		end
	end

	if #dirs == 1 then
		return vim.fs.basename(dirs[1])
	end
end

local function paired_paths(module_root, rel)
	local include_prefix = detect_include_prefix(module_root)
	local header_root = module_root .. "/include"
	if include_prefix then
		header_root = header_root .. "/" .. include_prefix
	end

	return header_root .. "/" .. rel .. ".hpp", module_root .. "/src/" .. rel .. ".cpp", include_prefix
end

local function join_rel(base, rel)
	if not base or base == "" then
		return rel
	end
	if not rel or rel == "" then
		return base
	end
	return base .. "/" .. rel
end

local function creation_context()
	local dir = current_dir()
	local module_root = module_root_from_path(dir) or module_root_from_path(vim.uv.cwd())
	if not module_root then
		return nil
	end

	local include_dir = module_root .. "/include"
	local include_prefix = detect_include_prefix(module_root)
	local header_dir = include_dir
	if include_prefix then
		header_dir = include_dir .. "/" .. include_prefix
	end

	local src_dir = module_root .. "/src"

	local rel = relative_to(dir, header_dir)
	if rel ~= nil then
		return module_root, rel
	end

	rel = relative_to(dir, src_dir)
	if rel ~= nil then
		return module_root, rel
	end

	if normalize(dir) == normalize(include_dir) or normalize(dir) == normalize(module_root) then
		return module_root, ""
	end

	return module_root, ""
end

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "cpp-pairs" })
end

local function sanitize_rel(rel)
	rel = (rel or ""):gsub("^%s+", ""):gsub("%s+$", "")
	rel = rel:gsub("\\", "/")
	rel = rel:gsub("^/+", "")
	rel = strip_extension(rel)
	return rel
end

local function write_file_if_missing(path, lines)
	if is_file(path) then
		return false
	end

	vim.fn.mkdir(dirname(path), "p")
	vim.fn.writefile(lines, path)
	return true
end

local function include_target(include_prefix, rel)
	if include_prefix then
		return include_prefix .. "/" .. rel .. ".hpp"
	end

	return rel .. ".hpp"
end

local function split_path(path)
	return vim.split(normalize(path), "/", { trimempty = true })
end

local function relative_path(from_dir, to_path)
	local from_parts = split_path(from_dir)
	local to_parts = split_path(to_path)
	local common = 1

	while common <= #from_parts and common <= #to_parts and from_parts[common] == to_parts[common] do
		common = common + 1
	end

	local rel_parts = {}
	for _ = common, #from_parts do
		rel_parts[#rel_parts + 1] = ".."
	end

	for i = common, #to_parts do
		rel_parts[#rel_parts + 1] = to_parts[i]
	end

	return table.concat(rel_parts, "/")
end

local function class_name_from_rel(rel)
	local name = rel:match("([^/]+)$") or rel
	local parts = vim.split(name, "[^%w]+", { trimempty = true })
	if #parts == 0 then
		return "TypeName"
	end

	for i, part in ipairs(parts) do
		parts[i] = part:sub(1, 1):upper() .. part:sub(2)
	end

	return table.concat(parts)
end

local function scaffold_lines(_, rel, header, source)
	local class_name = class_name_from_rel(rel)
	local include_path = relative_path(dirname(source), header)
	return {
		"#pragma once",
		"",
		"namespace woki {",
		"",
		"class " .. class_name .. " {",
		"public:",
		"    " .. class_name .. "();",
		"};",
		"",
		"} // namespace woki",
		"",
	}, {
		"#include \"" .. include_path .. "\"",
		"",
		"namespace woki {",
		"",
		class_name .. "::" .. class_name .. "() = default;",
		"",
		"} // namespace woki",
		"",
	}
end

local function parse_create_args(input)
	input = (input or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if input == "" then
		return nil, nil
	end

	local preset, rel = input:match("^(%S+)%s+(.+)$")
	if preset == "woki" and rel and rel ~= "" then
		return sanitize_rel(rel), preset
	end

	return sanitize_rel(input), "basic"
end

local function find_counterpart(path)
	local module_root = module_root_from_path(path)
	if not module_root then
		return nil, "Not inside modules/<name>"
	end

	local include_dir = module_root .. "/include"
	local src_dir = module_root .. "/src"
	local stem = strip_extension(path)

	local rel = relative_to(stem, src_dir)
	if rel then
		local header, _, _ = paired_paths(module_root, rel)
		local header_stem = strip_extension(header)
		for _, ext in ipairs(header_exts) do
			local candidate = header_stem .. ext
			if is_file(candidate) then
				return candidate
			end
		end

		return header
	end

	rel = relative_to(stem, include_dir)
	if rel then
		local include_prefix = detect_include_prefix(module_root)
		if include_prefix then
			local prefix = include_prefix .. "/"
			if rel:sub(1, #prefix) == prefix then
				rel = rel:sub(#prefix + 1)
			end
		end

		local source = src_dir .. "/" .. rel .. ".cpp"
		local source_stem = strip_extension(source)
		for _, ext in ipairs(source_exts) do
			local candidate = source_stem .. ext
			if is_file(candidate) then
				return candidate
			end
		end

		return source
	end

	return nil, "Current file is not inside include/ or src/"
end

function M.create_pair(rel, preset)
	local opened_from_oil = vim.bo.filetype == "oil"
	rel = sanitize_rel(rel)
	preset = preset or "basic"
	if rel == "" then
		notify("Pair path is required", vim.log.levels.WARN)
		return
	end

	local module_root, base_rel = creation_context()
	if not module_root then
		notify("Open a file inside modules/<name> first", vim.log.levels.WARN)
		return
	end

	rel = join_rel(base_rel, rel)

	local header, source = paired_paths(module_root, rel)
	local header_lines, source_lines = scaffold_lines(preset, rel, header, source)
	local created = {}

	if write_file_if_missing(header, header_lines) then
		created[#created + 1] = header
	end

	if write_file_if_missing(source, source_lines) then
		created[#created + 1] = source
	end

	if #created == 0 then
		notify("Pair already exists")
		return
	end

	if opened_from_oil then
		local ok, actions = pcall(require, "oil.actions")
		if ok and actions.close and actions.close.callback then
			actions.close.callback()
		end
		vim.cmd.edit(vim.fn.fnameescape(header))
	end

	notify("Created pair for " .. rel)
end

function M.prompt_create_pair()
	local input = vim.fn.input("C++ pair path or 'woki path': ")
	if input == "" then
		return
	end

	local rel, preset = parse_create_args(input)
	if not rel or rel == "" then
		notify("Pair path is required", vim.log.levels.WARN)
		return
	end

	M.create_pair(rel, preset)
end

function M.switch()
	local target, err = find_counterpart(current_path())
	if not target then
		notify(err, vim.log.levels.WARN)
		return
	end

	vim.fn.mkdir(dirname(target), "p")
	vim.cmd.edit(vim.fn.fnameescape(target))
end

function M.setup()
	if did_setup then
		return
	end

	did_setup = true

	vim.api.nvim_create_user_command("CppCreatePair", function(opts)
		local rel, preset = parse_create_args(opts.args)
		if not rel or rel == "" then
			notify("Pair path is required", vim.log.levels.WARN)
			return
		end

		M.create_pair(rel, preset)
	end, {
		nargs = "+",
		complete = "file",
		desc = "Create paired C++ header/source files",
	})

	vim.api.nvim_create_user_command("CppAlternate", function()
		M.switch()
	end, {
		desc = "Open paired C++ header/source file",
	})
end

return M
