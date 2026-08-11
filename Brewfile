# Every tool the configs in this repo actually call. `setup-and-install.sh` runs
# `brew bundle` before linking, so a fresh machine has the tools by the time the
# configs that call them arrive.
#
# This is the single source of packages on both machines. On Linux and WSL, apt
# installs only Homebrew's own prerequisites plus zsh (the login shell); every
# formula below has an x86_64_linux bottle, so nothing here builds from source
# under WSL.
#
#   brew bundle            install what is missing
#   brew bundle check      report what is missing, install nothing
#   brew bundle cleanup    list installed packages that are not listed here

# Core
brew "git"            # newer than the distro's, and the same on both machines

# Shell
brew "starship"       # prompt, driven from zshrc
brew "fzf"            # required by the fo() and po() helpers
brew "gh"             # required by po(), and by the git credential helper
brew "eza"            # ls/ll/la/lt aliases
brew "bat"            # cat with highlighting
brew "zoxide"         # the z command
brew "fd"             # friendlier find, used by fzf

# Editor
brew "neovim"
brew "ripgrep"        # telescope live_grep
brew "lazygit"        # <leader>gg in nvim
brew "git-delta"      # git pager, wired up in gitconfig

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
# Pulls in brew's node and typescript. nvm's node still comes first on PATH,
# so this only backs the language server, it does not take over your toolchain.
brew "typescript-language-server"
