# ~/.zshrc — symlinked from ~/dotfiles/zshrc
#
# No framework. What oh-my-zsh provided (completion, history, keybindings) is
# spelled out here in about twenty lines; its git aliases were being redefined
# further down anyway.

# ---------------------------------------------------------------------------
# PATH and Homebrew
# ---------------------------------------------------------------------------
# /opt/homebrew on macOS (Apple Silicon), linuxbrew on Linux and WSL. On macOS
# ~/.zprofile already does this with `brew shellenv`; this is the safety net.
for _brew in /opt/homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    [ -x "$_brew" ] && eval "$("$_brew" shellenv)" && break
done
unset _brew

# typeset -U keeps $path free of duplicates, so `sf` does not keep growing it.
typeset -U path PATH
path=("$HOME/.local/bin" $path)

# ---------------------------------------------------------------------------
# History
# ---------------------------------------------------------------------------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000              # oh-my-zsh saved 10000 while loading 50000

setopt extended_history         # record timestamp and duration per command
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_ignore_space        # a line starting with a space is not recorded
setopt hist_verify              # !! expands for review instead of running
setopt share_history            # history shared across open shells
setopt inc_append_history

# ---------------------------------------------------------------------------
# Shell options
# ---------------------------------------------------------------------------
setopt auto_cd                  # typing a bare path cds into it
setopt auto_pushd               # every cd pushes; `cd -<TAB>` lists where you have been
setopt pushd_ignore_dups
setopt extended_glob
setopt interactive_comments     # allow # comments on the interactive line
setopt no_beep

# ---------------------------------------------------------------------------
# Completion
# ---------------------------------------------------------------------------
# Rebuilding the dump on every startup costs ~20 ms, so it is only regenerated
# when it is more than a day old; the rest of the time it loads with -C.
autoload -Uz compinit
_zdump="${ZDOTDIR:-$HOME}/.zcompdump"
if [[ -n ${_zdump}(#qN.mh+24) ]]; then
    compinit -d "$_zdump"
else
    compinit -C -d "$_zdump"
fi
unset _zdump

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'   # complete case-insensitively
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"

# ---------------------------------------------------------------------------
# Keys
# ---------------------------------------------------------------------------
bindkey -e                                      # emacs mode

# Up/Down search history by what is already typed, not blindly.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

bindkey '^[[1;5C' forward-word                  # Ctrl+Right
bindkey '^[[1;5D' backward-word                 # Ctrl+Left
bindkey '^[[3~'   delete-char

# ---------------------------------------------------------------------------
# Prompt
# ---------------------------------------------------------------------------
# Guarded: on a machine where starship is not installed we want the plain
# zsh prompt, not an error on every single startup.
command -v starship >/dev/null && eval "$(starship init zsh)"

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
# Config
alias efc='nvim ~/.zshrc'
alias sf='source ~/.zshrc'
alias evc='nvim ~/.config/nvim'

# eza: `ls` with colours by type, icons and git status.
# All guarded: on a machine without eza this falls back to the normal `ls`
# rather than leaving the terminal with no `ls` at all.
if command -v eza >/dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza --icons --group-directories-first --long --git --header'
    alias la='eza --icons --group-directories-first --long --git --header --all'
    alias lt='eza --icons --group-directories-first --tree --level=2'
fi

# bat: `cat` with syntax highlighting.
# On Debian/Ubuntu the binary is called `batcat`, not `bat`: the `bat` name was
# already taken by the bacula-console-qt package. Everywhere else it is `bat`.
command -v batcat >/dev/null && alias bat='batcat'

# Git
alias gst='git status'
alias gaa='git add -A'
alias gc='git commit'
alias gcm='git checkout main'
alias gd='git diff'
alias gdc='git diff --cached'
alias co='git checkout'
alias gup='git push'
alias upf='git push --force-with-lease'   # plain --force overwrites whatever someone else pushed
alias pu='git pull'
alias pur='git pull --rebase'
alias fe='git fetch'
alias re='git rebase'
alias lr='git l -30'
alias cdr='cd $(git rev-parse --show-toplevel)'
alias hs='git rev-parse --short HEAD'
alias hm='git log --format=%B -n 1 HEAD'

alias bear='clear && echo "Clear as a bear!"'

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------
vim() {
    nvim "$@"
}

# Walk up the tree to the first directory whose name contains $1.
up() {
    if [ -z "$1" ]; then
        echo "Usage: , directory_name"
        return 1
    fi

    local current_path="$PWD"
    while [ "$current_path" != "/" ]; do
        local parent_dir="$(dirname "$current_path")"
        local matching_dir="$(find "$parent_dir" -maxdepth 1 -type d -name "*$1*" | head -n 1)"

        if [ -n "$matching_dir" ]; then
            cd "$matching_dir"
            return 0
        fi

        current_path="$parent_dir"
    done

    echo "No directory matching '$1' was found"
    return 1
}
# This used to be `.`, which is the POSIX source builtin: it broke
# `. venv/bin/activate` and anything else copied out of a README.
alias ,='up'

# Fuzzy checkout over branches sorted by date.
fo() {
    local branch
    branch=$(git branch --no-color --sort=-committerdate --format='%(refname:short)' | fzf --header 'git checkout')
    [[ -n "$branch" ]] && git checkout "$branch"
}

# Check out one of your own PRs.
po() {
    local pr_branch
    pr_branch=$(gh pr list --author "@me" | fzf --header 'checkout PR' | awk '{print $(NF-5)}')
    [[ -n "$pr_branch" ]] && git checkout "$pr_branch"
}

# ---------------------------------------------------------------------------
# Toolchains
# ---------------------------------------------------------------------------
# nvm: sourcing nvm.sh costs ~200 ms, two thirds of the whole startup. Instead
# the bin directory of the `default` version goes straight onto PATH — which is
# all that node/npm/npx need — and nvm itself loads the first time it is called.
export NVM_DIR="$HOME/.nvm"
() {
    emulate -L zsh
    setopt local_options null_glob numeric_glob_sort

    local marker=''
    [ -r "$NVM_DIR/alias/default" ] && marker=$(<"$NVM_DIR/alias/default")

    local -a candidates
    case "$marker" in
        v*)         candidates=("$NVM_DIR/versions/node/$marker"/bin) ;;
        ''|lts/*)   candidates=("$NVM_DIR/versions/node"/v*/bin) ;;
        *)          candidates=("$NVM_DIR/versions/node/v${marker}"/bin
                                "$NVM_DIR/versions/node/v${marker}".*/bin) ;;
    esac

    # numeric_glob_sort orders by number, so the last one is the highest.
    (( $#candidates )) && path=("${candidates[-1]}" $path)
}

nvm() {
    unset -f nvm
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm "$@"
}

# pnpm — the default location differs between macOS and Linux/WSL
if [[ "$OSTYPE" == darwin* ]]; then
    export PNPM_HOME="$HOME/Library/pnpm"
else
    export PNPM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/pnpm"
fi
path=("$PNPM_HOME" $path)

# bun
export BUN_INSTALL="$HOME/.bun"
path=("$BUN_INSTALL/bin" $path)
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"

# rust (rustup): puts cargo, rustfmt and rust-analyzer on PATH.
[ -s "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# go: binaries installed with `go install`
[ -d "$HOME/go/bin" ] && path=("$HOME/go/bin" $path)

# fzf shell integration: Ctrl+R over history, Ctrl+T to insert a path, Alt+C to
# cd into a directory. Without this fzf is only ever reached through the fo()
# and po() helpers above, which is most of the tool left on the table.
# Needs compinit already run, hence its place down here.
if command -v fzf >/dev/null; then
    source <(fzf --zsh)

    # fd backs the file and directory pickers: it honours .gitignore and skips
    # .git, which plain find does not.
    if command -v fd >/dev/null; then
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
    fi
fi

# zoxide: `cd` that remembers where you go most — `z proj` from anywhere.
# Deliberately last: it hooks into the prompt and wants compinit already done.
# It does not touch `cd`, so the `up` function and its `,` alias are unaffected;
# it adds `z` and `zi`, the latter with an fzf picker.
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

# >>> railway initialize >>>
# Guarded with -f: on a machine without the Railway CLI (a freshly set up WSL,
# say) a bare `source` fails on every single zsh startup.
[ -f "$HOME/.railway/env" ] && source "$HOME/.railway/env"
# <<< railway initialize <<<
