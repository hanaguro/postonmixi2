local M = {}

local function post_to_mixi2(text, callback)
  -- mixi2post コマンドに投稿テキストを引数として渡す
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
        callback(false, msg)
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        callback(false, "mixi2post exited with code " .. code)
      end
    end,
  })
end

function M.auth()
  -- 設定ファイルの場所を案内するだけ（認証はenv変数で管理）
  local env_file = vim.fn.expand("~/.config/mixi2/env")
  vim.notify(
    "[postonmixi2] 認証情報を以下のファイルに設定してください:\n"
    .. env_file .. "\n\n"
    .. "MIXI2_CLIENT_ID=...\n"
    .. "MIXI2_CLIENT_SECRET=...\n"
    .. "MIXI2_TOKEN_URL=https://auth.mixi.social/oauth2/token\n"
    .. "MIXI2_API_ADDRESS=api.mixi.social:443\n\n"
    .. "設定後: source " .. env_file,
    vim.log.levels.INFO
  )
  -- エディタでenvファイルを開く
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
end

function M.open_compose()
  -- 既存の mixi2://compose バッファを削除する
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
  vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
    virt_text = { { "  mixi2投稿ウィンドウ — :w で投稿、q でキャンセル  ", "Comment" } },
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
      -- 149文字制限チェック
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
          vim.schedule(function()
            if vim.api.nvim_win_is_valid(win) then
              vim.api.nvim_win_close(win, true)
            end
          end)
        else
          vim.notify("[postonmixi2] エラー: " .. msg, vim.log.levels.ERROR)
        end
      end)
    end,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
    noremap = true, silent = true,
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

  vim.keymap.set("n", opts.keymap or "s", function()
    M.open_compose()
  end, { noremap = true, silent = true, desc = "Open mixi2 compose window" })
end

return M
