return {
  -- messages, cmdline and the popupmenu
  {
    "folke/noice.nvim",
    opts = function(_, opts)
      table.insert(opts.routes, {
        filter = {
          event = "notify",
          find = "No information available",
        },
        opts = { skip = true },
      })
      local focused = true
      vim.api.nvim_create_autocmd("FocusGained", {
        callback = function()
          focused = true
        end,
      })
      vim.api.nvim_create_autocmd("FocusLost", {
        callback = function()
          focused = false
        end,
      })
      table.insert(opts.routes, 1, {
        filter = {
          cond = function()
            return not focused
          end,
        },
        view = "notify_send",
        opts = { stop = false },
      })

      opts.commands = {
        all = {
          -- options for the message history that you get with `:Noice`
          view = "split",
          opts = { enter = true, format = "details" },
          filter = {},
        },
      }

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function(event)
          vim.schedule(function()
            require("noice.text.markdown").keys(event.buf)
          end)
        end,
      })

      opts.presets.lsp_doc_border = true
    end,
  },

  {
    "rcarriga/nvim-notify",
    opts = {
      timeout = 5000,
    },
  },

  {
    "snacks.nvim",
    opts = {
      scroll = { enabled = false },
    },
    keys = {},
  },

  -- buffer line
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    keys = {
      { "<Tab>", "<Cmd>BufferLineCycleNext<CR>", desc = "Next tab" },
      { "<S-Tab>", "<Cmd>BufferLineCyclePrev<CR>", desc = "Prev tab" },
    },
    opts = {
      options = {
        mode = "tabs",
        -- separator_style = "slant",
        show_buffer_close_icons = false,
        show_close_icon = false,
      },
    },
  },

  -- filename

  -- statusline
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      local LazyVim = require("lazyvim.util")
      opts.sections.lualine_c[4] = {
        LazyVim.lualine.pretty_path({
          length = 0,
          relative = "cwd",
          modified_hl = "MatchParen",
          directory_hl = "",
          filename_hl = "Bold",
          modified_sign = "",
          readonly_icon = " 󰌾 ",
        }),
      }
    end,
  },

  {
    "folke/zen-mode.nvim",
    cmd = "ZenMode",
    opts = {
      plugins = {
        gitsigns = true,
        tmux = true,
        kitty = { enabled = false, font = "+2" },
      },
    },
    keys = { { "<leader>z", "<cmd>ZenMode<cr>", desc = "Zen Mode" } },
  },

  {
    "MeanderingProgrammer/render-markdown.nvim",
    enabled = false,
  },

  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          header = [[
            ██╗  ███╗░░░███╗██╗░██████╗░██████╗  ██╗░░░██╗░█████╗░██╗░░░██╗  ███╗░░██╗░█████╗░
            ██║  ████╗░████║██║██╔════╝██╔════╝  ╚██╗░██╔╝██╔══██╗██║░░░██║  ████╗░██║██╔══██╗
            ██║  ██╔████╔██║██║╚█████╗░╚█████╗░  ░╚████╔╝░██║░░██║██║░░░██║  ██╔██╗██║███████║
            ██║  ██║╚██╔╝██║██║░╚═══██╗░╚═══██╗  ░░╚██╔╝░░██║░░██║██║░░░██║  ██║╚████║██╔══██║
            ██║  ██║░╚═╝░██║██║██████╔╝██████╔╝  ░░░██║░░░╚█████╔╝╚██████╔╝  ██║░╚███║██║░░██║
            ╚═╝  ╚═╝░░░░░╚═╝╚═╝╚═════╝░╚═════╝░  ░░░╚═╝░░░░╚════╝░░╚═════╝░  ╚═╝░░╚══╝╚═╝░░╚═╝
          ]],
        },
      },
      sections = {
        section = "terminal",
        cmd = "chafa ~/.config/wall.png --format symbols --symbols --vhalf --size 60x17 --stretech; sleep .1",
        height = 17,
        padding = 1,
      },
      {
        pane = 2,
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
      },
    },
  },
}
