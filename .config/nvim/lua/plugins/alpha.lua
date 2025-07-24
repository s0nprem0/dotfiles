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
      dashboard.button("f", "  Find file", ":lua require('fzf-lua').files({ cwd = '~' })<CR>"),
      dashboard.button("r", "  Recent files", ":lua require('fzf-lua').oldfiles({ cwd_only = true })<CR>"),
      dashboard.button("p", "  Plugins", ":Lazy<CR>"),
      dashboard.button("q", "  Quit", ":qa<CR>"),
    }

    local function footer()
      local stats = require("lazy").stats()
      local v = vim.version()

      -- Date and time formatting
      local time_str = os.date("%I:%M:%S %p"):gsub("^0", " ")
      local date_str = os.date("%a %d %b %Y")

      -- Base footer string
      local footer_str = string.format(
        "󰂖 %d plugins   v%d.%d.%d   %s   %s",
        stats.count,
        v.major,
        v.minor,
        v.patch,
        date_str,
        time_str
      )

      return footer_str
    end

    -- Set initial footer
    dashboard.section.footer.val = footer()

    -- Update with startup time after plugins load
    vim.api.nvim_create_autocmd("User", {
      pattern = "LazyVimStarted",
      callback = function()
        local stats = require("lazy").stats()
        local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)
        dashboard.section.footer.val = string.format(
          "%s  󱐋 %dms",
          footer(), -- Original footer content
          ms -- Startup time in milliseconds
        )
        pcall(vim.cmd.AlphaRedraw)
      end,
    })

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
