local function repo_url()
  local handle = io.popen("git remote get-url origin 2>/dev/null")
  if not handle then
    return nil
  end
  local url = handle:read("*l"):gsub("%.git$", "")
  handle:close()
  if url:match("github%.com") then
    return url:gsub("git@github%.com:", "https://github.com/")
  end
  return url
end

return {
  "vyfor/cord.nvim",
  event = "VeryLazy",
  config = function()
    require("cord").setup({
      display = {
        view = "asset",
        show_cursor = true,
      },

      idle = {
        enabled = true,
        timeout = 300,
      },

      editor = {
        name = "Neovim",
      },

      buttons = {
        {
          label = "View Repository",
          url = repo_url() or "",
        },
      },

      hooks = {
        post_activity = function(opts, activity)
          local workspace = opts.workspace or vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
          local filename = opts.filename
          local filetype = opts.filetype or ""

          activity.state = filename and ("Editing " .. filename .. (filetype ~= "" and " (" .. filetype .. ")" or "")) or ("Working on " .. workspace)
          activity.details = workspace

          return activity
        end,
      },
    })
  end,
}
