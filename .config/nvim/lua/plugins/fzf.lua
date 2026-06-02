return {
  "ibhagwan/fzf-lua",
  opts = {
    winopts = {
      width = 0.8,
      height = 0.8,
      preview = {
        horizontal = "right:60%",
      },
    },
    files = {
      fd_opts = "--hidden --no-ignore-vcs --strip-cwd-prefix",
    },
    grep = {
      rg_opts = "--hidden --no-ignore-vcs --column --line-number --smart-case",
    },
  },
}
