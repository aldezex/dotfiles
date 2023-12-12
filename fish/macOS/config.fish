set -gx PATH /Users/alvaro/.local/bin:/Users/alvaro/.cabal/bin:/Users/alvaro/.ghcup/bin:/Users/alvaro/.pyenv/shims:/Users/alvaro/.nvm/versions/node/v18.9.1/bin:/Users/alvaro/.sdkman/candidates/maven/current/bin:/Users/alvaro/.sdkman/candidates/java/current/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin:/Library/Apple/usr/bin:/usr/local/go/bin:/Users/alvaro/.cargo/bin

starship init fish | source

function vim
    nvim $argv
end
