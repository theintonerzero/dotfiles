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
