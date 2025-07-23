return {
  "goolord/alpha-nvim",
  event = "VimEnter",
  dependencies = {
    "ibhagwan/fzf-lua",
    "nvim-tree/nvim-web-devicons",
  },
  config = function()
    local alpha = require("alpha")
    local dashboard = require("alpha.themes.dashboard")

    -- Custom header with ASCII art
    dashboard.section.header.val = {
      [[                               __                ]],
      [[  ___     ___    ___   __  __ /\_\    ___ ___    ]],
      [[ / _ `\  / __`\ / __`\/\ \/\ \\/\ \  / __` __`\  ]],
      [[/\ \/\ \/\  __//\ \_\ \ \ \_/ |\ \ \/\ \/\ \/\ \ ]],
      [[\ \_\ \_\ \____\ \____/\ \___/  \ \_\ \_\ \_\ \_\]],
      [[ \/_/\/_/\/____/\/___/  \/__/    \/_/\/_/\/_/\/_/]],
    }

    -- Custom buttons
    dashboard.section.buttons.val = {
      dashboard.button("e", "  New file", ":ene <BAR> startinsert <CR>"),
      dashboard.button("f", "  Find file", ":lua require('fzf-lua').files({ cwd = '~' })<CR>"),
      dashboard.button("r", "  Recent files", ":lua require('fzf-lua').oldfiles({ cwd_only = true })<CR>"),
      dashboard.button("g", "  Live grep", ":lua require('fzf-lua').grep({ search = '' })<CR>"),
      dashboard.button("p", "  Plugins", ":Lazy<CR>"),
      dashboard.button("q", "  Quit", ":qa<CR>"),
    }

    -- Footer with dynamic content
    local function footer()
      local datetime = os.date(" %Y-%m-%d   %H:%M:%S")
      local stats = require("lazy").stats()
      local plugins_count = " " .. stats.count .. " plugins"
      local version = vim.version()
      local nvim_version = " v" .. version.major .. "." .. version.minor .. "." .. version.patch

      return plugins_count .. "  " .. nvim_version .. "  " .. datetime
    end

    dashboard.section.footer.val = footer
    dashboard.section.footer.opts.hl = "Comment"

    -- Layout configuration
    dashboard.config.layout = {
      { type = "padding", val = 3 },
      dashboard.section.header,
      { type = "padding", val = 3 },
      dashboard.section.buttons,
      { type = "padding", val = 2 },
      dashboard.section.footer,
    }

    -- Apply the configuration
    alpha.setup(dashboard.config)

    -- Hide statusline and tabline when Alpha is active
    vim.api.nvim_create_autocmd("User", {
      pattern = "AlphaReady",
      callback = function()
        vim.opt.laststatus = 0
        vim.opt.showtabline = 0
      end,
    })

    vim.api.nvim_create_autocmd("BufUnload", {
      buffer = 0,
      callback = function()
        vim.opt.laststatus = 3
        vim.opt.showtabline = 2
      end,
    })
  end,
}
