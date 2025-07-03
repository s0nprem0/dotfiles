return {
  "williamboman/mason.nvim",
  dependencies = {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    "williamboman/mason-lspconfig.nvim", -- Recommended for LSP integration
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

    -- Tool installer setup
    require("mason-tool-installer").setup({
      ensure_installed = {
        -- LSPs
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

    -- Recommended: LSP config setup
    require("mason-lspconfig").setup({
      automatic_installation = true, -- Auto-install LSPs listed in lspconfig
    })
  end,
}
