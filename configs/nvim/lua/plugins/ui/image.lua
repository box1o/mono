return {
	{
		"3rd/image.nvim",
		event = "VeryLazy",
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {
			backend = "kitty",
			kitty_method = "normal",
			window_overlap_clear_enabled = true,
			integrations = {
				markdown = {
					enabled = true,
					clear_in_insert_mode = false,
					download_remote_images = true,
					only_render_image_at_cursor = false,
					filetypes = { "markdown", "vimwiki" },
				},
			},
		},
		config = function(_, opts)
			local ok_image, image = pcall(require, "image")
			if not ok_image then
				return
			end

			-- kitty backend needs tmux passthrough, otherwise image.nvim throws.
			if opts.backend == "kitty" and vim.env.TMUX then
				local passthrough = vim.trim(vim.fn.system("tmux show -gv allow-passthrough 2>/dev/null"))
				if vim.v.shell_error ~= 0 or passthrough ~= "on" then
					return
				end
			end

			local ok_setup = pcall(image.setup, opts)
			if not ok_setup then
				return
			end

			local allowed_ext = { "png", "jpg", "jpeg", "gif", "webp", "bmp" }
			local watchers = {}
			local reload_timers = {}

			local function is_supported_image(path)
				local ext = path:match("%.([%w]+)$")
				return ext and vim.tbl_contains(allowed_ext, ext:lower())
			end

			local function clear_watch(bufnr)
				local watcher = watchers[bufnr]
				if watcher then
					watcher:stop()
					watcher:close()
					watchers[bufnr] = nil
				end

				local timer = reload_timers[bufnr]
				if timer then
					timer:stop()
					timer:close()
					reload_timers[bufnr] = nil
				end
			end

			local function render_image(bufnr)
				local path = vim.api.nvim_buf_get_name(bufnr)
				if path == "" or not is_supported_image(path) then
					return
				end

				local win = vim.fn.bufwinid(bufnr)
				if win == -1 then
					return
				end

				vim.api.nvim_win_call(win, function()
					image.clear()
					local img = image.from_file(path, {
						window = win,
						buffer = bufnr,
						with_virtual_padding = true,
					})
					if img then
						img:render()
					end
				end)
			end

			local function setup_watch(bufnr)
				clear_watch(bufnr)

				local path = vim.api.nvim_buf_get_name(bufnr)
				if path == "" or not is_supported_image(path) then
					return
				end

				local watcher = vim.uv.new_fs_event()
				if not watcher then
					return
				end

				watcher:start(path, {}, vim.schedule_wrap(function()
					if not vim.api.nvim_buf_is_valid(bufnr) then
						clear_watch(bufnr)
						return
					end

					local timer = reload_timers[bufnr]
					if timer then
						timer:stop()
						timer:close()
					end

					timer = vim.uv.new_timer()
					reload_timers[bufnr] = timer
					timer:start(50, 0, vim.schedule_wrap(function()
						if vim.api.nvim_buf_is_valid(bufnr) then
							render_image(bufnr)
						end
						if reload_timers[bufnr] then
							reload_timers[bufnr]:stop()
							reload_timers[bufnr]:close()
							reload_timers[bufnr] = nil
						end
					end))
				end))

				watchers[bufnr] = watcher
			end

			vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
				callback = function(args)
					setup_watch(args.buf)
				end,
			})

			vim.api.nvim_create_autocmd({ "BufUnload", "BufWipeout" }, {
				callback = function(args)
					clear_watch(args.buf)
				end,
			})

			vim.api.nvim_create_user_command("ImagePreview", function()
				local path = vim.api.nvim_buf_get_name(0)
				if path == "" then
					vim.notify("No file path to preview", vim.log.levels.WARN)
					return
				end

				local stat = vim.uv.fs_stat(path)
				if not stat or stat.type ~= "file" then
					vim.notify("Not a file: " .. path, vim.log.levels.WARN)
					return
				end

				if not is_supported_image(path) then
					vim.notify("Unsupported image type", vim.log.levels.WARN)
					return
				end

				render_image(0)
				setup_watch(0)
			end, { desc = "Preview current image in buffer" })

			vim.api.nvim_create_user_command("ImageClear", function()
				image.clear()
			end, { desc = "Clear images in current buffer" })
		end,
	},
}
