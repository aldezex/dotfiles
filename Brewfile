# Packages the configs in this repo actually depend on. `install.sh` runs
# `brew bundle` at the end, so a fresh machine gets the tools before the
# configs that call them get linked.
#
# Works the same on macOS and on Linuxbrew under WSL.
#
#   brew bundle            install what is missing
#   brew bundle check      report what is missing, install nothing
#   brew bundle cleanup    list installed packages that are not listed here

# Shell
brew "starship"       # prompt, driven from zshrc
brew "fzf"            # required by the fo() and po() helpers
brew "gh"             # required by po()

# Editor
brew "neovim"
brew "ripgrep"        # telescope live_grep
brew "lazygit"        # <leader>gg in nvim

# Claude Code
brew "jq"             # statusline.sh parses its stdin with it
                      # (macOS ships /usr/bin/jq, WSL does not)

# Formatters wired into conform.nvim
brew "stylua"         # lua
brew "shfmt"          # sh
brew "biome"          # js / ts / jsx / tsx

# Language servers configured in nvim/lua/plugins/lsp.lua
brew "lua-language-server"
brew "gopls"
brew "rust-analyzer"
