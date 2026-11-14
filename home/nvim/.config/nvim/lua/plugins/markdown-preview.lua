-- markdown-preview's own build fetches its server in a terminal, which a headless install quits
-- too soon; its install script, run straight, finishes first
-- a server (one with a lua/machine.lua that says so) has neither
local on_server, machine = pcall(require, "machine")
if on_server and type(machine) == "table" and machine.server == true then return {} end

---@type LazySpec
return {
  "iamcco/markdown-preview.nvim",
  build = "cd app && ./install.sh",
}
