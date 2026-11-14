-- shared/neovim-parsers.lua: waits for the treesitter parsers the config asks for. neovim fetches and
-- compiles them by itself as it starts, in the background, so a run with no screen is over before they're
-- there; a parser already being installed is waited for, not installed twice
local wanted = require("astrocore").config.treesitter.ensure_installed
if type(wanted) ~= "table" then return end
local finished, installed = pcall(function() return require("nvim-treesitter").install(wanted):wait(600000) end)
if not finished or not installed then
  if not finished then io.stderr:write(tostring(installed) .. "\n") end
  vim.cmd "cquit"
end
