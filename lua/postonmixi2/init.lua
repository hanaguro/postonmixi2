local M = {}
local bluesky = false

local function post_to_mixi2(text, callback)
	local cmd = { "mixi2post", text }

	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		on_stdout = function(_, data)
			local post_id = vim.trim(table.concat(data, ""))
			if post_id ~= "" then
				callback(true, "Posted! ID: " .. post_id)
			else
				callback(true, "Posted!")
			end
		end,
		on_stderr = function(_, data)
			local msg = vim.trim(table.concat(data, ""))
			if msg ~= "" then
				-- エラーメッセージの構造化解析
				local translated_msg = msg
				if msg:find("^ERR_AUTH:") then
					translated_msg = "認証エラーが発生しました。:PostOnMixi2 auth で設定を確認してください。"
				elseif msg:find("^ERR_CONFIG:") then
					translated_msg = "設定ファイルの読み込みに失敗しました。"
				elseif msg:find("^ERR_CONN:") then
					translated_msg = "mixi2 サーバーへの接続に失敗しました。"
				end
				callback(false, translated_msg)
			end
		end,
		on_exit = function(_, code)
			if code ~= 0 then
				callback(false, "mixi2post exited with code " .. code)
			end
		end,
	})
end

local function post_to_bluesky(text, callback)
	local cmd = { "bsky", "post", text }

	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		on_stdout = function(_, data)
			local post_id = vim.trim(table.concat(data, ""))
			if post_id ~= "" then
				callback(true, "Posted! ID: " .. post_id)
			else
				callback(true, "Posted!")
			end
		end,
		on_stderr = function(_, data)
			local msg = vim.trim(table.concat(data, ""))
			if msg ~= "" then
				callback(false, msg)
			end
		end,
		on_exit = function(_, code)
			if code ~= 0 then
				callback(false, "bsky post exited with code " .. code)
			end
		end,
	})
end

function M.auth()
	local env_file = vim.fn.expand("~/.config/mixi2/env")
	vim.notify(
		"[postonmixi2] 認証情報を以下のファイルに設定してください:\n"
			.. env_file .. "\n\n"
			.. "CLIENT_ID=...\n"
			.. "CLIENT_SECRET=...\n"
			.. "TOKEN_URL=...\n"
			.. "API_ADDRESS=...\n\n",
		vim.log.levels.INFO
	)

	vim.fn.mkdir(vim.fn.fnamemodify(env_file, ":h"), "p")
	vim.cmd("edit " .. env_file)
end

function M.send(text)
	if not text or text == "" then
		vim.notify("[postonmixi2] 投稿テキストがありません。", vim.log.levels.WARN)
		return
	end
	vim.notify("[postonmixi2] 投稿中...", vim.log.levels.INFO)
	
	post_to_mixi2(text, function(ok, msg)
		if ok then
			vim.notify("[postonmixi2] " .. msg, vim.log.levels.INFO)
		else
			vim.notify("[postonmixi2] エラー: " .. msg, vim.log.levels.ERROR)
		end
	end)

	if bluesky then
		post_to_bluesky(text, function(ok, msg)
			if ok then
				vim.notify("[bsky post] " .. msg, vim.log.levels.INFO)
			else
				vim.notify("[bsky post] エラー: " .. msg, vim.log.levels.ERROR)
			end
		end)
	end
end

function M.open_compose()
	local existing = vim.fn.bufnr("mixi2://compose")
	if existing ~= -1 then
		vim.api.nvim_buf_delete(existing, { force = true })
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "buftype", "acwrite")
	vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
	vim.api.nvim_buf_set_option(buf, "buflisted", false)
	vim.api.nvim_buf_set_name(buf, "mixi2://compose")

	vim.cmd("botright 10split")
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)
	vim.api.nvim_win_set_option(win, "wrap", true)
	vim.api.nvim_win_set_option(win, "linebreak", true)
	vim.api.nvim_win_set_option(win, "number", false)
	vim.api.nvim_win_set_option(win, "relativenumber", false)
	vim.api.nvim_win_set_option(win, "signcolumn", "no")
	vim.api.nvim_win_set_option(win, "statusline",
		" [mixi2 Compose]  :w で投稿して閉じる | q でキャンセル (最大149文字) ")

	local ns = vim.api.nvim_create_namespace("postonmixi2_hint")
	local virtual_text = "  mixi2投稿ウィンドウ — :w で投稿、q でキャンセル  "
	if bluesky then
		virtual_text = "  mixi2/bluesky投稿ウィンドウ — :w で投稿、q でキャンセル  "
	end
	vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
		virt_text = { { virtual_text, "Comment" } },
		virt_text_pos = "overlay",
		hl_mode = "replace",
	})

	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = buf,
		callback = function()
			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			local text = table.concat(lines, "\n"):match("^%s*(.-)%s*$")
			if text == "" then
				vim.notify("[postonmixi2] 投稿内容がありません。", vim.log.levels.WARN)
				return
			end
			if vim.fn.strchars(text) > 149 then
				vim.notify(
					"[postonmixi2] 文字数超過: " .. vim.fn.strchars(text) .. "/149文字",
					vim.log.levels.ERROR
				)
				return
			end
			vim.api.nvim_buf_set_option(buf, "modified", false)
			vim.notify("[postonmixi2] 投稿中...", vim.log.levels.INFO)
			post_to_mixi2(text, function(ok, msg)
				if ok then
					vim.notify("[postonmixi2] " .. msg, vim.log.levels.INFO)
					if not bluesky then
						vim.schedule(function()
							if vim.api.nvim_win_is_valid(win) then
								vim.api.nvim_win_close(win, true)
							end
						end)
					end
				else
					vim.notify("[postonmixi2] エラー: " .. msg, vim.log.levels.ERROR)
				end
			end)
			if bluesky then
				post_to_bluesky(text, function(ok, msg)
					if ok then
						vim.notify("[bsky post] " .. msg, vim.log.levels.INFO)
						vim.schedule(function()
							if vim.api.nvim_win_is_valid(win) then
								vim.api.nvim_win_close(win, true)
							end
						end)
					else
						vim.notify("[bsky post] エラー: " .. msg, vim.log.levels.ERROR)
					end
				end)
			end
		end,
	})

	vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
		noremap = true,
		silent = true,
		callback = function()
			vim.api.nvim_buf_set_option(buf, "modified", false)
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
		end,
	})

	vim.cmd("startinsert")
end

function M.command(args)
	local parts = vim.split(args, "%s+", { trimempty = true })
	local subcmd = parts[1]
	if subcmd == "auth" then
		M.auth()
	elseif subcmd == "send" then
		M.send(args:match("^send%s+(.+)$"))
	else
		vim.notify(
			"[postonmixi2] 使い方:\n  :PostOnMixi2 auth\n  :PostOnMixi2 send <投稿内容>",
			vim.log.levels.ERROR
		)
	end
end

function M.setup(opts)
	opts = opts or {}
	vim.api.nvim_create_user_command("PostOnMixi2", function(o)
		M.command(o.args)
	end, {
		nargs = "+",
		complete = function(_, line)
			local p = vim.split(line, "%s+", { trimempty = true })
			if #p <= 1 or (#p == 2 and not line:match("%s$")) then
				return { "auth", "send" }
			end
			return {}
		end,
		desc = "Post to mixi2",
	})

	local desc_str = "Open mixi2 compose window"
	if opts.bluesky then
		bluesky = true
		desc_str = "Open mixi2/bluesky compose window"
	end
	vim.keymap.set("n", opts.keymap or "s", function()
		M.open_compose()
	end, { noremap = true, silent = true, desc = desc_str })
end

return M
