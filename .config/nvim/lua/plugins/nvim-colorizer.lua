return {
  "catgoose/nvim-colorizer.lua",
  config = function()
    require("colorizer").setup({
      user_default_options = {
        RGB = true,
        RRGGBB = true,
        RRGGBBAA = true,
        names = false,
        css = true,
        mode = "backgrgound",
        virtualtext = "*",
        always_update = true,
      },

      filetypes = {
        "css",
        "scss",
        "less",
        "html",
        "javascript",
        "typescript",
        "lua",

        html = {
          rgb_fn = false,
          hsl_fn = false,
        },
      },
    })
  end,
}
