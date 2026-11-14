-- shared/neovim-parsers.lua: waits for the treesitter parsers the config asks for. neovim fetches and
-- compiles them by itself as it starts, in the background, so a run with no screen is over before they're
-- there. they're asked for here too and waited for; neovim's own pass may be on the same parsers, and then
-- this wait comes back early with no for an answer, so what's checked is whether the parsers are there,
-- once the ones still under way have had time to land
local wanted = require("astrocore").config.treesitter.ensure_installed
if type(wanted) ~= "table" then return end
local treesitter = require "nvim-treesitter"

local function missing()
  local there, lacking = {}, {}
  for _, parser in ipairs(treesitter.get_installed "parsers") do
    there[parser] = true
  end
  for _, parser in ipairs(wanted) do
    if not there[parser] then table.insert(lacking, parser) end
  end
  return lacking
end

-- an install can fall over on what an earlier neovim left half done, which that same install clears
-- away as it starts: so what's still missing is asked for again, three times at most
local lacking = wanted
for _ = 1, 3 do
  pcall(function() treesitter.install(lacking):wait(600000) end)
  vim.wait(60000, function() return #missing() == 0 end, 500)
  lacking = missing()
  if #lacking == 0 then break end
end
if #lacking > 0 then
  io.stderr:write("no parser for: " .. table.concat(lacking, " ") .. "\n")
  vim.cmd "cquit"
end
