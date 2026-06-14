-- 空のテーブル（= オブジェクト）を作成・代入
local M = {}

local function post_to_mixi2(text, callback)
	-- mixi2post コマンドに投稿テキストを引数として渡す
	local cmd = { "mixi2post", text }

	vim.fn.jobstart(cmd, {
		-- stdout_buffered = true にすると プロセスが終了して出力が全部揃ってから1回だけ呼ばれる
		stdout_buffered = true,
		-- 本来はfunction(job_id, data, event) だがforce_idとeventは使わないので次の形になる
		-- data は外部プロセスの標準出力を行ごとに分割した文字列の配列
		on_stdout = function(_, data)
			-- table.concat(data, "") で配列を1つの文字列に結合し、vim.trim() で余分な空白・改行を除去
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
				callback(false, "mixi2post exited with code " .. code)
			end
		end,
	})
end -- ← 【修正】ここにあった余剰なendを整理し、関数の終端として正しく配置

function M.auth()
	-- 設定ファイルの場所を案内するだけ（認証はenv変数で管理）
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

	-- エディタでenvファイルを開く

	-- vim.fn.fnamemodify(): ファイル名からパスの特定の部分を抜き取る Vim 関数
	-- ":h" は「head（ファイル名の先頭部分）＝ 親ディレクトリ」を意味する修飾子
	-- vim.fn.mkdir(dir, "p"): ディレクトリを作成する Vim 関数
	-- "p" は「parents（親ディレクトリも連番で作成）」オプション
	vim.fn.mkdir(vim.fn.fnamemodify(env_file, ":h"), "p")
	-- vim.cmd(): Vim コマンドを実行する Vim 関数
	vim.cmd("edit " .. env_file)
end

function M.send(text)
	if not text or text == "" then
		vim.notify("[postonmixi2] 投稿テキストがありません。", vim.log.levels.WARN)
		return
	end
	vim.notify("[postonmixi2] 投稿中...", vim.log.levels.INFO)
	-- function(ok, msg) ... end でその場で無名関数を作り、post_to_mixi2()の第二引数として渡す
	post_to_mixi2(text, function(ok, msg)
		if ok then
			vim.notify("[postonmixi2] " .. msg, vim.log.levels.INFO)
		else
			vim.notify("[postonmixi2] エラー: " .. msg, vim.log.levels.ERROR)
		end
	end)
end

function M.open_compose()
	-- 既存の mixi2://compose バッファを削除する。
	-- vim.fn.bufnr(name) は、指定した名前のバッファの番号 を返す Vim 関数。
	local existing = vim.fn.bufnr("mixi2://compose")
	if existing ~= -1 then
		-- vim.api.nvim_buf_delete(bufnr, opts) は、指定したバッファを削除（閉じる）。
		vim.api.nvim_buf_delete(existing, { force = true })
	end

	-- nvim_create_buf(created, listed) は、新しいバッファを作成する API 
	-- 第1引数 false → 「ファイルとして存在しないバッファ」（空のスクラッチバッファ）
	-- 第2引数 true → 「リストに含まれるバッファ」（:ls などで表示される）
	local buf = vim.api.nvim_create_buf(false, true)
	-- buftype はバッファの「型」を指定するオプション。
	-- "acwrite" は、:write を実行した時に BufWriteCmd イベントを受け取る 特殊なバッファ型。
	-- BufWriteCmd で投稿処理をしてウィンドウを閉じている。
	vim.api.nvim_buf_set_option(buf, "buftype", "acwrite")
	-- filetype はバッファの「ファイルタイプ」。
	vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
	-- buflisted は「リストに表示するか」を指定。
	-- nvim_create_buf の第 2 引数で true にしたあと、ここで false にしているが、
	-- これは「一時的にリストに入れて、そのあとリストから隠す」という意図。
	vim.api.nvim_buf_set_option(buf, "buflisted", false)
	-- nvim_buf_set_name(buf, name) は、バッファに名前（識別子）を付ける API。
	vim.api.nvim_buf_set_name(buf, "mixi2://compose")

	-- "botright 10split" は、「画面の一番下（botright）に、10 行高のウィンドウ分割（10split）」 を行うコマンド。
	vim.cmd("botright 10split")
	-- nvim_get_current_win() は、現在のウィンドウの番号 を返す API。
	local win = vim.api.nvim_get_current_win()
	-- nvim_win_set_buf(win, buf) は、指定したウィンドウに、指定したバッファを表示させる API。
	vim.api.nvim_win_set_buf(win, buf)
	-- wrap = true → 行が長すぎても折り返して表示する
	vim.api.nvim_win_set_option(win, "wrap", true)
	-- linebreak = true → 折り返しポイントを適切な位置（文字の境界）
	vim.api.nvim_win_set_option(win, "linebreak", true)
	-- number = false → 行番号を表示しない
	vim.api.nvim_win_set_option(win, "number", false)
	-- relativenumber = false → 相対行番号も表示しない
	vim.api.nvim_win_set_option(win, "relativenumber", false)
	-- signcolumn = "no" → 左端のシグナル列（デバッグマーカー等）を表示しない
	vim.api.nvim_win_set_option(win, "signcolumn", "no")
	-- statusline は、そのウィンドウのステータスライン（行）に表示する文字列 
	vim.api.nvim_win_set_option(win, "statusline",
		" [mixi2 Compose]  :w で投稿して閉じる | q でキャンセル (最大149文字) ")

	-- バッファの特定の位置に「仮想テキスト（visible な文字列ではなく、
	-- Neovim 側で描画するテキスト）」を重ねて表示する処理。
	local ns = vim.api.nvim_create_namespace("postonmixi2_hint")
	-- nvim_buf_set_extmark(buf, ns, line, col, opts) は、指定したバッファの特定の行・列に
	-- extmark（拡張マーカー）をセットする API。
	vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
		-- virt_text は、仮想テキスト（virtual text） を指定するオプション。
		-- テキストの内容と、そのハイライトグループを { texto, "group" } の配列で書く。
		-- ハイライト: "Comment"（Neovim の標準ハイライトグループ、コメント色）
		virt_text = { { "  mixi2投稿ウィンドウ — :w で投稿、q でキャンセル  ", "Comment" } },
		-- virt_text_pos は、仮想テキストをどこに置くか を指定するオプション。
		-- "overlay" → 指定した列（col_num）にテキストを重ねて表示する。
		virt_text_pos = "overlay",
		-- hl_mode は、仮想テキストのハイライトが既存のハイライトとどう扱うか を指定。
		-- "replace" → 既存のハイライトを 上書き する
		hl_mode = "replace",
	})

	-- nvim_create_autocmd() は、自動コマンド（イベント）を登録する API
	-- "BufWriteCmd" は、:write などの保存コマンドが実行されたときに発火するイベント
	vim.api.nvim_create_autocmd("BufWriteCmd", {
		-- buffer = buf → このイベントは 特定のバッファ（compose バッファ）にだけ適用 される
		buffer = buf,
		-- callback = function() → イベントが発火したときに実行される処理
		callback = function()
			-- vim.api.nvim_buf_get_lines() は、Neovim の API でバッファの指定した行範囲のテキストを取得する関数
			-- バッファ番号(buf)、開始番号(0)、終了番号(-1)、範囲外でも安全に処理(false)
			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			-- (.-)はluaの最短一致を表わす
			local text = table.concat(lines, "\n"):match("^%s*(.-)%s*$")
			if text == "" then
				vim.notify("[postonmixi2] 投稿内容がありません。", vim.log.levels.WARN)
				return
			end
			-- 149文字制限チェック
			if vim.fn.strchars(text) > 149 then
				vim.notify(
					"[postonmixi2] 文字数超過: " .. vim.fn.strchars(text) .. "/149文字",
					vim.log.levels.ERROR
				)
				return
			end
			-- modified オプションは、バッファが「変更されている（保存していない）」かどうかを示す。
			vim.api.nvim_buf_set_option(buf, "modified", false)
			vim.notify("[postonmixi2] 投稿中...", vim.log.levels.INFO)
			post_to_mixi2(text, function(ok, msg)
				if ok then
					vim.notify("[postonmixi2] " .. msg, vim.log.levels.INFO)
					-- vim.schedule(callback) は、Neovim のメインイベントループに、
					-- ある関数を「少し後に」実行するよう予約する関数
					vim.schedule(function()
						-- ウィンドウがまだ存在しているか確認
						if vim.api.nvim_win_is_valid(win) then
							-- ウィンドウを 強制閉じる（true は保存チェック無視）
							vim.api.nvim_win_close(win, true)
						end
					end)
				else
					vim.notify("[postonmixi2] エラー: " .. msg, vim.log.levels.ERROR)
				end
			end)
		end,
	})

	-- vim.api.nvim_buf_set_keymap() は、特定バッファにだけ有効なキーマップを設定
	-- buf は対象バッファ番号
	-- "n" はノーマルモードを意味
	-- "q" は押すキー
	-- 置換後文字列が "" なのは、実際の動作を文字列展開ではなく callback 側で行うため
	vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
		-- noremap = true は再帰マップしない設定で、q がさらに別のマップへ展開されるのを防ぐ
		noremap = true,
		-- silent = true は実行時にコマンドラインへ余計な表示を出さない設定
		silent = true,
		-- callback = function() は、q を押したときに Lua 関数を直接実行するためのもの
		callback = function()
			-- そのバッファを「未変更ではない」、つまり保存確認不要の状態にする
			vim.api.nvim_buf_set_option(buf, "modified", false)
			if vim.api.nvim_win_is_valid(win) then
				-- 第2引数 true は強制クローズで、保存確認などを無視して閉じる指定
				vim.api.nvim_win_close(win, true)
			end
		end,
	})

	-- vim.cmd("startinsert") は、Neovim を挿入モードに切り替えるコマンド
	vim.cmd("startinsert")
end

-- M.command() は、vim.api.nvim_create_user_command("PostOnMixi2", ...) から呼ばれる
-- コマンド本体のディスパッチャ 
function M.command(args)
	-- args を空白で分割して、単語の配列にする処理
	-- { trimempty = true } 連続した空白や末尾の空白で空文字が混ざるのを避けるためのオプション
	local parts = vim.split(args, "%s+", { trimempty = true })
	-- luaの配列は1から始まる
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

-- M.setup(opts) は、プラグインの初期設定をまとめる入口
-- 利用者側は require("postonmixi2").setup() を呼ぶだけで、
--    :PostOnMixi2 auth
--    :PostOnMixi2 send ...
--    ノーマルモード s で compose ウィンドウ
-- が使えるようになる
function M.setup(opts)
	-- opts が nil なら空テーブル {} を入れる
	opts = opts or {}
	-- ユーザー定義 Ex コマンド :PostOnMixi2 を登録
	-- function(o) ... end コマンドが実行されたときに呼ばれる関数
	-- o.args に、auth や send こんにちは のような引数文字列が入る
	vim.api.nvim_create_user_command("PostOnMixi2", function(o)
		M.command(o.args)
	end, {
		-- nargs = "+"引数を 1個以上 受け取る設定。PostOnMixi2単体ではなく、
		-- 少なくともauthかsendが必要になる
		nargs = "+",
		-- コマンド補完候補 を返す関数
		-- lineは入力中のコマンド全体
		complete = function(_, line)
			local p = vim.split(line, "%s+", { trimempty = true })
			-- #p の # は、Lua では 長さ演算子
			-- not line:match("%s$") は、末尾に空白がないことを意味する
			if #p <= 1 or (#p == 2 and not line:match("%s$")) then
				return { "auth", "send" }
			end
			return {}
		end,
		desc = "Post to mixi2",
	})

	-- ノーマルモードのキー割り当て
	-- "n"はノーマルモードでのみ有効
	-- opts.keymap or "s"はopts.keymap が設定されていればそれを使い、なければ s を使う
	vim.keymap.set("n", opts.keymap or "s", function()
		M.open_compose()
	-- noremap = trueは再帰マッピングしない
	-- silent = trueは余計なメッセージを出さない
	-- desc = ...はキーマップの説明
	end, { noremap = true, silent = true, desc = "Open mixi2 compose window" })
end

return M
