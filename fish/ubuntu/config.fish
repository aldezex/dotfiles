starship init fish | source
alias vim="nvim"
set -gx PATH $HOME/.cargo/bin $PATH

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

set -gx JAVA_HOME /usr/lib/jvm/java-11-openjdk-amd64
set -gx PATH $JAVA_HOME/bin $PATH

bash -c '~/sdkman_init.sh'
