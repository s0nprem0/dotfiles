return {
  {
    "catppuccin/nvim",
    lazy = false,
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "macchiato",
        transparent_background = true,
        term_colors = true,
        styles = {
          comments = { "italic" },
          conditionals = { "italic" },
        },
      })
      -- Set the theme
      vim.cmd.colorscheme "catppuccin"
    end
  }
}
