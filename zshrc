export ZSH="$HOME/.oh-my-zsh"
plugins=(git)

source $ZSH/oh-my-zsh.sh

# PATH — va ANTES que nada que se ejecute al cargar este fichero.
# starship, nvim, fzf, gh, fd y go viven en ~/.local/bin: si el PATH se montara
# al final (donde lo dejan los instaladores), la línea de starship de aquí abajo
# se ejecutaría con un PATH que todavía no lo contiene y el arranque de cada
# terminal soltaría un «command not found: starship» — sin prompt de starship.
export PATH="/opt/homebrew/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# Initialize starship prompt
# Con guarda: si un día starship no está instalado, no queremos un error en cada
# arranque, sólo el prompt de oh-my-zsh.
command -v starship >/dev/null && eval "$(starship init zsh)"

# Config editing aliases
alias efc='nvim ~/.zshrc'
alias sf='source ~/.zshrc'

# eza: `ls` con colores por tipo, iconos y estado de git.
# Todo bajo guarda: en una máquina sin eza se cae al `ls` de siempre en vez de
# dejar la terminal sin `ls`.
if command -v eza >/dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza --icons --group-directories-first --long --git --header'
    alias la='eza --icons --group-directories-first --long --git --header --all'
    alias lt='eza --icons --group-directories-first --tree --level=2'
fi

# bat: `cat` con resaltado de sintaxis.
# En Debian/Ubuntu el binario se llama `batcat`, no `bat`: el nombre `bat` ya lo
# ocupaba el paquete bacula-console-qt. En macOS y en el resto es `bat` a secas.
command -v batcat >/dev/null && alias bat='batcat'

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


# pnpm
if [ -z "${PNPM_HOME:-}" ]; then
  case "$(uname -s)" in
    Darwin) export PNPM_HOME="$HOME/Library/pnpm" ;;
    *)      export PNPM_HOME="$HOME/.local/share/pnpm" ;;
  esac
fi
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# (/opt/homebrew/bin y ~/.local/bin se montan arriba del todo, a propósito.)

# rust (rustup): pone cargo, rustfmt y rust-analyzer en el PATH.
# `\.` y no `.` porque más arriba `.` está aliaseado a la función `up`.
[ -s "$HOME/.cargo/env" ] && \. "$HOME/.cargo/env"

# go: binarios instalados con `go install`
[ -d "$HOME/go/bin" ] && export PATH="$HOME/go/bin:$PATH"

# zoxide: `cd` con memoria de los sitios más visitados — `z mtgg` desde donde sea.
# Va al FINAL a propósito: engancha un hook al prompt y quiere el compinit que
# hace oh-my-zsh ya cerrado. No toca `cd`, así que la función `up` y el alias `.`
# siguen exactamente igual; añade `z` y `zi` (este último con selector fzf).
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
