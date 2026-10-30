-- markdown-preview's own build fetches its server in a terminal, which a headless install quits
-- too soon; its install script, run straight, finishes first
---@type LazySpec
return {
  "iamcco/markdown-preview.nvim",
  build = "cd app && ./install.sh",
}
