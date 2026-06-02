return {
  "vyfor/cord.nvim",
  event = "VeryLazy",
  config = function()
    require("cord").setup({
      display = {
        theme = "catppuccin",
        flavor = "dark",
      },
    })
  end,
}
