# Java configuration
export JAVA_HOME=/Users/alvaro/.sdkman/candidates/java/8.0.352.fx-zulu
export PATH=$JAVA_HOME/bin:$PATH

# Path configuration
export PATH=/Users/alvaro/.local/bin:/Users/alvaro/.cabal/bin:/Users/alvaro/.ghcup/bin:/Users/alvaro/.pyenv/shims:/Users/alvaro/.nvm/versions/node/v20.11.1/bin:/Users/alvaro/.sdkman/candidates/maven/current/bin:/Users/alvaro/.sdkman/candidates/java/current/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin:/Library/Apple/usr/bin:/usr/local/go/bin:/Users/alvaro/.cargo/bin

# Initialize starship prompt
eval "$(starship init zsh)"

# Vim alias
vim() {
    nvim "$@"
}

# Config editing aliases
alias efc='nvim ~/.zshrc'
alias sf='source ~/.zshrc'

# Git aliases
alias gst='git status'
alias gaa='git add -A'
alias gc='git commit'
alias gcm='git checkout main'
alias gd='git diff'
alias gdc='git diff --cached'
alias co='git checkout'

# Fuzzy checkout function
fo() {
    local branch
    branch=$(git branch --no-color --sort=-committerdate --format='%(refname:short)' | fzf --header 'git checkout')
    [[ -n "$branch" ]] && git checkout "$branch"
}

# PR checkout function
po() {
    local pr_branch
    pr_branch=$(gh pr list --author "@me" | fzf --header 'checkout PR' | awk '{print $(NF-5)}')
    [[ -n "$pr_branch" ]] && git checkout "$pr_branch"
}

alias gup='git push'
alias upf='git push --force'
alias pu='git pull'
alias pur='git pull --rebase'
alias fe='git fetch'
alias re='git rebase'
alias lr='git l -30'
alias cdr='cd $(git rev-parse --show-toplevel)' # cd to git Root
alias hs='git rev-parse --short HEAD'
alias hm='git log --format=%B -n 1 HEAD'

# Vim config alias
alias evc='nvim ~/.config/nvim'

# Fun alias
alias bear='clear && echo "Clear as a bear!"'

# Tmux aliases
alias etm='nvim ~/.tmux.conf'
alias tma='tmux attach -t'
alias tmn='tmux new -s'
alias tmm='tmux new -s main'
alias kts='tmux kill-server'
alias lts='tmux list-sessions'

# pnpm configuration
export PNPM_HOME="/Users/alvaro/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"

# GHCup configuration
[ -z "$GHCUP_INSTALL_BASE_PREFIX" ] && export GHCUP_INSTALL_BASE_PREFIX=$HOME
export PATH="$HOME/.cabal/bin:$PATH:/Users/alvaro/.ghcup/bin"

# Navigate up function
up() {
    if [ -z "$1" ]; then
        echo "Uso: .nombre_directorio"
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
    
    echo "No se encontró un directorio que coincida con '$1'"
    return 1
}

# Alias for up function
alias .='up'
