return {
  "neovim/nvim-lspconfig",
  dependencies = {
    -- Mason (LSP/tool installer)
    { "williamboman/mason.nvim", opts = {} },
    "williamboman/mason-lspconfig.nvim",
    "WhoIsSethDaniel/mason-tool-installer.nvim",

    -- UI enhancements
    { "j-hui/fidget.nvim", opts = {} }, -- LSP progress notifications
  },
  config = function()
    -- ========================================
    -- 1. LSP Keymaps (on attach)
    -- ========================================
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("user-lsp-attach", { clear = true }),
      callback = function(event)
        local map = function(keys, func, desc, mode)
          mode = mode or "n"
          vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
        end

        -- Navigation
        map("gd", require("fzf-lua").lsp_definitions, "[G]oto [D]efinition")
        map("gr", require("fzf-lua").lsp_references, "[G]oto [R]eferences")
        map("gI", require("fzf-lua").lsp_implementations, "[G]oto [I]mplementation")
        map("<leader>D", require("fzf-lua").lsp_type_definitions, "Type [D]efinition")
        map("<leader>ds", require("fzf-lua").lsp_document_symbols, "[D]ocument [S]ymbols")
        map("<leader>ws", require("fzf-lua").lsp_workspace_symbols, "[W]orkspace [S]ymbols")

        -- Actions
        map("<leader>cr", vim.lsp.buf.rename, "[C]ode [R]ename")
        map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction", { "n", "v" })

        -- Diagnostics
        map("gl", vim.diagnostic.open_float, "Show diagnostic [L]ine")
        map("[d", vim.diagnostic.goto_prev, "Previous diagnostic")
        map("]d", vim.diagnostic.goto_next, "Next diagnostic")

        -- Inlay hints (toggle)
        if vim.lsp.inlay_hint then
          map("<leader>th", function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
          end, "[T]oggle [H]ints")
        end
      end,
    })

    -- ========================================
    -- 2. Diagnostic Configuration
    -- ========================================
    vim.diagnostic.config({
      virtual_text = {
        prefix = "●",
        spacing = 4,
      },
      signs = true,
      underline = true,
      update_in_insert = false,
      severity_sort = true,
      float = {
        border = "rounded",
        source = "always",
      },
    })

    -- Custom signs for diagnostics
    local signs = { Error = "󰅚 ", Warn = "󰀪 ", Hint = "󰌶 ", Info = "󰋽 " }
    for type, icon in pairs(signs) do
      local hl = "DiagnosticSign" .. type
      vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
    end

    -- ========================================
    -- 3. LSP Capabilities (for autocompletion)
    -- ========================================
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

    -- ========================================
    -- 4. Language Servers Setup
    -- ========================================
    local servers = {
      lua_ls = {
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            diagnostics = { globals = { "vim" } },
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
          },
        },
      },
      pyright = {},
      bashls = {},
      -- Add other LSPs here (e.g., "gopls", "rust_analyzer")
    }

    -- ========================================
    -- 5. Mason Tool Installer
    -- ========================================
    require("mason-tool-installer").setup({
      ensure_installed = {
        -- LSPs
        "lua_ls",
        "pyright",
        "bashls",
        -- Formatters/Linters
        "stylua",
        "prettierd",
        "black", -- Python formatter
      },
      auto_update = true,
    })

    -- ========================================
    -- 6. Mason LSPConfig (Auto-LSP Setup)
    -- ========================================
    require("mason-lspconfig").setup({
      automatic_installation = true,
      handlers = {
        function(server_name)
          local server = servers[server_name] or {}
          server.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server.capabilities or {})
          require("lspconfig")[server_name].setup(server)
        end,
      },
    })
  end,
}
