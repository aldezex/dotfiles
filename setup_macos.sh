#!/bin/bash


# Check if homebrew is installed
# If not, install it
if command -v brew &> /dev/null 2>&1; then
    echo "Homebrew found. Updating..."
    brew update
else
    echo "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Check if we have vim installed
# If not, install it
if command -v vim &> /dev/null 2>&1; then
    echo "Vim found. Updating..."
    brew install vim
else
    echo "Vim not found. Installing..."
    brew install vim
fi

# Check if we have neovim installed
# If not, install it
if command -v nvim &> /dev/null 2>&1; then
    echo "Neovim found. Updating..."
    brew install neovim
else
    echo "Neovim not found. Installing..."
    brew install neovim
fi

# Check if we have nvm installed
# If not, install it
#if command -v nvm &> /dev/null 2>&1; then
#    echo "NVM found."
#else
#    echo "NVM not found. Installing..."
#    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
#
#    export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
#    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
#
#    nvm install 18.9
#fi

# Check if we have iterm2 installed
# If not, install it
#if command -v iterm2 &> /dev/null 2>&1; then
#    echo "iTerm2 found."
#else
#    echo "iTerm2 not found. Installing..."
##    brew install --cask iterm2
#fi

# Download mirage theme for iterm2
# curl -o ~/Downloads/mirage.itermcolors https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/schemes/Ayu%20Mirage.itermcolors
# echo "Mirage theme for iTerm2 downloaded."

# Check if we have fish installed
# If not, install it
if command -v fish &> /dev/null 2>&1; then
    echo "Fish found."
else
    echo "Fish not found. Installing..."
    brew install fish
fi

# Check if we have fisher installed
# If not, install it
if command -v fisher &> /dev/null 2>&1; then
    echo "Fisher found."
else
    echo "Fisher not found. Installing..."
    brew install fisher
fi

# Check if we have starship installed
# If not, install it
if command -v starship &> /dev/null 2>&1; then
    echo "Starship found."
else
    echo "Starship not found. Installing..."
    brew install starship
fi

# Move configurations from ./nvim/macOS to ~/.config/nvim
echo "Moving nvim configurations..."
mkdir -p ~/.config/nvim
cp -r ./nvim/macOS/* ~/.config/nvim

# Move configurations from ./fish/macOS to ~/.config/fish
echo "Moving fish configurations..."
mkdir -p ~/.config/fish
cp -r ./fish/macOS/* ~/.config/fish
