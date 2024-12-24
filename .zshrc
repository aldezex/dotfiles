export ZSH="$HOME/.oh-my-zsh"
plugins=(git)

source $ZSH/oh-my-zsh.sh

# Initialize starship prompt
eval "$(starship init zsh)"

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

# Git aliases
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

# Vim alias
vim() {
    nvim "$@"
}

# NVM
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

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
