-- vim's options
---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    options = {
      opt = {
        number = true,
        relativenumber = true,
        spell = true,
        spelllang = { "en_au", "en_us" },
        signcolumn = "yes",
        colorcolumn = "100",
        wrap = false,
      },
    },
  },
}
