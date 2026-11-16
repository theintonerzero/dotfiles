-- astrocommunity: a pack for each language (server, formatter, linter, debugger, treesitter), then
-- the extras that make neovim an ide
-- a server keeps only the packs for what's edited there and the extras that need nothing installed
-- beside them; a pack's value here is whether a server has it too. a machine is a server when it has
-- a lua/machine.lua that says so, which only ubuntu server links: a file, not a variable, so every way
-- of starting neovim agrees
local on_server, machine = pcall(require, "machine")
local server = on_server and type(machine) == "table" and machine.server == true
local imports = {
  { "pack.lua", true },
  { "pack.bash", true },
  { "pack.json", true },
  { "pack.yaml", true },
  { "pack.toml", true },
  { "pack.markdown", true },
  { "pack.godot", false },
  { "pack.python", false },
  { "pack.rust", false },
  { "pack.go", false },
  { "pack.cpp", false },
  { "pack.cmake", false },
  { "pack.cs", false },
  { "pack.java", false },
  { "pack.kotlin", false },
  { "pack.zig", false },
  { "pack.typescript", false },
  { "pack.html-css", false },
  { "completion.blink-copilot", false },
  { "ai.claudecode-nvim", false },
  { "media.cord-nvim", false },
  { "markdown-and-latex.render-markdown-nvim", true },
  { "markdown-and-latex.markdown-preview-nvim", false },
  { "diagnostics.trouble-nvim", true },
  { "git.diffview-nvim", true },
  { "test.neotest", false },
  { "debugging.nvim-dap-virtual-text", false },
  { "code-runner.overseer-nvim", false },
  { "search.grug-far-nvim", true },
  { "motion.nvim-surround", true },
  { "colorscheme.kanagawa-nvim", true },
}

---@type LazySpec
local spec = { "AstroNvim/astrocommunity" }
for _, import in ipairs(imports) do
  if not server or import[2] then table.insert(spec, { import = "astrocommunity." .. import[1] }) end
end
return spec
