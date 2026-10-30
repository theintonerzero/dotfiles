-- godot's scripts in neovim: the first neovim in a godot project serves it on the project's socket,
-- and ~/.local/bin/godot-nvim, godot's external editor, opens each script there at godot's line and column
local M = {}

-- the socket for <project>: $XDG_RUNTIME_DIR/godot-nvim/, then the first 16 hex digits of the sha-256 of
-- the project's real path, as godot-nvim names it; nil without XDG_RUNTIME_DIR or the folder
function M.socket(project)
  local runtime = vim.env.XDG_RUNTIME_DIR
  local real = project and vim.uv.fs_realpath(project)
  if not runtime or runtime == "" or not real then return nil end
  return runtime .. "/godot-nvim/" .. vim.fn.sha256(real):sub(1, 16) .. ".sock"
end

-- serves the godot project of the current buffer, or of the folder neovim started in, unless a live
-- neovim already does; a socket nobody answers on, as a crash leaves, is replaced
function M.serve()
  local socket = M.socket(vim.fs.root(0, "project.godot"))
  if not socket then return nil end
  if vim.uv.fs_stat(socket) then
    local ok, chan = pcall(vim.fn.sockconnect, "pipe", socket, { rpc = true })
    if ok and chan > 0 then
      vim.fn.chanclose(chan)
      return nil
    end
    os.remove(socket)
  end
  vim.fn.mkdir(vim.fs.dirname(socket), "p", tonumber("700", 8))
  return pcall(vim.fn.serverstart, socket) and socket or nil
end

-- shows <file> as :drop does, at godot's <line> and <col>, counted from 1, the column in characters;
-- past the end means the last one; returns "" for godot-nvim's --remote-expr
function M.open(file, line, col)
  vim.cmd.drop(vim.fn.fnameescape(file))
  line = math.min(math.max(tonumber(line) or 1, 1), vim.api.nvim_buf_line_count(0))
  local text = vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]
  col = math.min(math.max(tonumber(col) or 1, 1), math.max(vim.fn.strchars(text), 1))
  vim.api.nvim_win_set_cursor(0, { line, vim.str_byteindex(text, "utf-32", col - 1, false) })
  return ""
end

return M
