# ~/.zprofile — symlinked from ~/dotfiles/zprofile
#
# Runs for login shells, including non-interactive ones, which is where
# ~/.zshrc never gets read. Homebrew only: everything else lives in the zshrc.

for _brew in /opt/homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    [ -x "$_brew" ] && eval "$("$_brew" shellenv)" && break
done
unset _brew
