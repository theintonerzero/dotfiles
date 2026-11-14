# tests/test_nvim.sh: neovim's config, where a step counts on it
# shellcheck shell=bash
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
if ! command -v nvim >/dev/null; then
  echo "  no nvim here, so its config isn't checked"
  exit 0
fi

# run_on_start <uis>: what the mason plugin's own pass at startup is set to, with that many screens attached
run_on_start() {
  cat >"$T/probe.lua" <<LUA
package.path = "$REPO/home/nvim/.config/nvim/lua/?.lua;" .. package.path
package.loaded.astrocore = { list_insert_unique = function(_, more) return more end }
vim.api.nvim_list_uis = function() return vim.list_slice({ {}, {} }, 1, $1) end
local spec = dofile("$REPO/home/nvim/.config/nvim/lua/plugins/mason.lua")
local opts = {}
spec.opts(nil, opts)
io.write(tostring(opts.run_on_start))
LUA
  nvim --clean -l "$T/probe.lua"
}

# with no screen, as dot install runs it, only MasonToolsInstallSync installs the tools: the plugin's own
# pass would start the same installs first, and the command then waits for good on installs it didn't start
eq "no pass of its own under dot install" false "$(run_on_start 0)"
eq "in the editor, its own pass stays" nil "$(run_on_start 1)"

# --- the server form: a machine that links lua/machine.lua saying so gets a smaller neovim ---

mkdir -p "$T/server"
echo 'return { server = true }' >"$T/server/machine.lua"
# probe <server|desktop> <lua>: runs the lua with the config's own modules on the path, and the server's
# machine.lua too when asked; astrocore's list_insert_unique stands in as itself
probe() {
  local extra=""
  if [[ $1 == server ]]; then extra="$T/server/?.lua;"; fi
  cat >"$T/probe.lua" <<LUA
package.path = "$extra$REPO/home/nvim/.config/nvim/lua/?.lua;" .. package.path
package.loaded.astrocore = { list_insert_unique = function(dst, more)
  dst = dst or {}
  for _, v in ipairs(more) do if not vim.tbl_contains(dst, v) then table.insert(dst, v) end end
  return dst
end }
$2
LUA
  nvim --clean -l "$T/probe.lua"
}
imports='local out = {} for _, s in ipairs(dofile("'$REPO'/home/nvim/.config/nvim/lua/community.lua")) do if type(s) == "table" and s.import then table.insert(out, (s.import:gsub("^astrocommunity%.", ""))) end end io.write(table.concat(out, " "))'

eq "a server's packs and extras" \
  "pack.lua pack.bash pack.json pack.yaml pack.toml pack.markdown markdown-and-latex.render-markdown-nvim diagnostics.trouble-nvim git.diffview-nvim search.grug-far-nvim motion.nvim-surround colorscheme.kanagawa-nvim" \
  "$(probe server "$imports")"
# off a server, every pack and extra, in the order they have always had
before="pack.lua pack.bash pack.json pack.yaml pack.toml pack.markdown pack.godot pack.python pack.rust pack.go pack.cpp pack.cs pack.java pack.kotlin pack.zig pack.typescript pack.html-css completion.blink-copilot ai.claudecode-nvim media.cord-nvim markdown-and-latex.render-markdown-nvim markdown-and-latex.markdown-preview-nvim diagnostics.trouble-nvim git.diffview-nvim test.neotest debugging.nvim-dap-virtual-text code-runner.overseer-nvim search.grug-far-nvim motion.nvim-surround colorscheme.kanagawa-nvim"
eq "a desktop's list is unchanged" "$before" "$(probe desktop "$imports")"

tools='local spec = dofile("'$REPO'/home/nvim/.config/nvim/lua/plugins/mason.lua") local opts = { ensure_installed = { "lua-language-server", "bash-language-server", "shfmt", "prettierd" } } spec.opts(nil, opts) io.write(table.concat(opts.ensure_installed, " "))'
eq "a server installs only tools that need no toolchain" "lua-language-server shfmt" "$(probe server "$tools")"
eq "a desktop installs them all, and its own three" \
  "lua-language-server bash-language-server shfmt prettierd pyright typescript-language-server kotlin-lsp" "$(probe desktop "$tools")"

for f in godot markdown-preview; do
  empty='local spec = dofile("'$REPO'/home/nvim/.config/nvim/lua/plugins/'$f'.lua") io.write(tostring(next(spec) == nil))'
  eq "$f is left out on a server" true "$(probe server "$empty")"
  eq "$f stays on a desktop" false "$(probe desktop "$empty")"
done

# only ubuntu links the file that says so
(load ubuntu && link_home) >/dev/null
ok "ubuntu says it's a server" grep -q 'server = true' "$HOME/.config/nvim/lua/machine.lua"
rm -rf "$HOME" && mkdir -p "$HOME"
(load fedora && link_home) >/dev/null
no "fedora doesn't" test -e "$HOME/.config/nvim/lua/machine.lua"
if [[ $(uname -s) == Darwin ]]; then
  rm -rf "$HOME" && mkdir -p "$HOME"
  (load macos && link_home) >/dev/null
  no "macos doesn't" test -e "$HOME/.config/nvim/lua/machine.lua"
fi

# --- the parsers a run with no screen waits for ---

# parsers <ensure_installed, as lua> <what install's wait gives, as lua> <the parsers there afterwards, as
# lua>: runs shared/neovim-parsers.lua against a stand-in nvim-treesitter that prints what it's asked to
# install; waiting for anything is over at once
parsers() {
  cat >"$T/probe.lua" <<LUA
package.loaded.astrocore = { config = { treesitter = { ensure_installed = $1 } } }
package.loaded["nvim-treesitter"] = {
  install = function(langs)
    io.write(table.concat(langs, " "), "\n")
    return { wait = function() $2 end }
  end,
  get_installed = function() return $3 end,
}
vim.wait = function(_, done) return done() end
dofile("$REPO/shared/neovim-parsers.lua")
LUA
  nvim --clean -l "$T/probe.lua" 2>/dev/null
}
eq "every parser the config asks for is asked for" "lua bash" "$(parsers '{ "lua", "bash" }' 'return true' '{ "bash", "lua", "c" }')"
# neovim's own pass may be installing the same parsers, and then the wait here comes back early saying
# no: what counts is whether the parsers are there
ok "an install that says no, with the parsers there, is fine" parsers '{ "lua" }' 'return false' '{ "lua" }' >/dev/null
ok "so is one that fell over, with the parsers there" parsers '{ "lua" }' 'error("busy")' '{ "lua" }' >/dev/null
no "a parser that isn't there is a failure" parsers '{ "lua", "bash" }' 'return true' '{ "lua" }' >/dev/null
no "none there is too" parsers '{ "lua" }' 'return false' '{}' >/dev/null
eq "a config that names none asks for none" "" "$(parsers '"auto"' 'return true' '{}')"
# a parser whose install fell over, as one does when a download an earlier neovim left half done is in
# its way, is asked for again by itself, and the run is fine once it's there
eq "what's still missing is asked for again" $'lua python\npython' \
  "$(parsers '{ "lua", "python" }' 'tries = (tries or 0) + 1' '(tries or 0) >= 2 and { "lua", "python" } or { "lua" }')"
ok "and a second try that lands is fine" parsers '{ "lua", "python" }' 'tries = (tries or 0) + 1' '(tries or 0) >= 2 and { "lua", "python" } or { "lua" }' >/dev/null
eq "three tries, then it gives up" 3 "$({ parsers '{ "lua" }' 'return false' '{}' || true; } | grep -c lua)"
