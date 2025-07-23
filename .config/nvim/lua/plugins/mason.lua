return {
  "mason-org/mason.nvim",
  dependencies = {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    "mason-org/mason-lspconfig.nvim", -- This dependency is still needed for mason to know about it, but its *setup* is in the lspconfig file.
  },
  opts = {
    ui = {
      icons = {
        package_installed = "✓",
        package_pending = "➜",
        package_uninstalled = "✗",
      },
    },
  },
  config = function(_, opts)
    require("mason").setup(opts)

    -- Tool installer setup (for formatters, linters, etc.)
    require("mason-tool-installer").setup({
      ensure_installed = {
        -- LSPs (Mason will install these, but lspconfig will configure them via the other file)
        "bash-language-server",
        "jdtls",
        "lua_ls",
        "pyright",

        -- Formatters (choose one of prettier/prettierd)
        "prettier",
        "stylua",

        -- Linters
        "shellcheck",
        "eslint_d",
      },
      auto_update = true,
      run_on_start = true, -- Set to false if startup is too slow
    })
  end,
}
