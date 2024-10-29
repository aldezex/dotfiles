set -gx JAVA_HOME /Users/alvaro/.sdkman/candidates/java/8.0.352.fx-zulu
set -gx PATH $JAVA_HOME/bin $PATH
set -gx PATH /Users/alvaro/.local/bin:/Users/alvaro/.cabal/bin:/Users/alvaro/.ghcup/bin:/Users/alvaro/.pyenv/shims:/Users/alvaro/.nvm/versions/node/v20.11.1/bin:/Users/alvaro/.sdkman/candidates/maven/current/bin:/Users/alvaro/.sdkman/candidates/java/current/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin:/Library/Apple/usr/bin:/usr/local/go/bin:/Users/alvaro/.cargo/bin

starship init fish | source
bass source ~/.sdkman/bin/sdkman-init.sh

function vim
    nvim $argv
end

# edit fish config
alias efc='nvim ~/.config/fish/config.fish'
alias sf='source ~/.config/fish/config.fish'

# git
alias gst='git status'
alias gaa='git add -A'
alias gc='git commit'
alias gcm='git checkout main'
alias gd='git diff'
alias gdc='git diff --cached'
# [c]heck [o]ut
alias co='git checkout'
# [f]uzzy check[o]ut
function fo
  git branch --no-color --sort=-committerdate --format='%(refname:short)' | fzf --header 'git checkout' | xargs git checkout
end
# [p]ull request check[o]ut
function po
  gh pr list --author "@me" | fzf --header 'checkout PR' | awk '{print $(NF-5)}' | xargs git checkout
end
alias gup='git push'
alias upf='git push --force'
alias pu='git pull'
alias pur='git pull --rebase'
alias fe='git fetch'
alias re='git rebase'
alias lr='git l -30'
alias cdr='cd (git rev-parse --show-toplevel)' # cd to git Root
alias hs='git rev-parse --short HEAD'
alias hm='git log --format=%B -n 1 HEAD'

# edit vim config
alias evc='nvim ~/.config/nvim'

# life is fun
alias bear='clear && echo "Clear as a bear!"'

# tmux
alias etm='nvim ~/.tmux.conf'
alias tma='tmux attach -t'
alias tmn='tmux new -s'
alias tmm='tmux new -s main'
alias kts='tmux kill-server'
alias lts='tmux list-sessions'

# pnpm
set -gx PNPM_HOME "/Users/alvaro/Library/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end

set -q GHCUP_INSTALL_BASE_PREFIX[1]; or set GHCUP_INSTALL_BASE_PREFIX $HOME ; set -gx PATH $HOME/.cabal/bin $PATH /Users/alvaro/.ghcup/bin # ghcup-env

# navigate up easily
function up --argument-names 'name'
    if test -z "$name"
        echo "Uso: .nombre_directorio"
        return 1
    end

    set current_path (pwd)
    while test "$current_path" != "/"
        set parent_dir (dirname "$current_path")
        set matching_dirs (find "$parent_dir" -maxdepth 1 -type d -name "*$name*")
        
        if test -n "$matching_dirs"
            cd $matching_dirs[1]
            return 0
        end
        
        set current_path "$parent_dir"
    end
    
    echo "No se encontró un directorio que coincida con '$name'"
    return 1
end

function . --wraps up
    up $argv
end
