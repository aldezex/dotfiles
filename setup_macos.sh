#!/bin/bash

# Check if homebrew is installed
# If not, install it
if command -v brew &> /dev/null 2>&1; then
    echo "Homebrew found." 
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

# clone Vundle if not already cloned
if [ ! -d ~/.vim/bundle/Vundle.vim ]; then
    echo "Vundle not found. Cloning..."
    git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
else
    echo "Vundle found. Updating..."
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

# Check if we have iterm2 installed
# If not, install it
#if command -v iterm2 &> /dev/null 2>&1; then
#    echo "iTerm2 found."
#else
#    echo "iTerm2 not found. Installing..."
##    brew install --cask iterm2
#fi

# Download mirage theme for iterm2
curl -o ~/Downloads/mirage.itermcolors https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/schemes/Ayu%20Mirage.itermcolors
echo "Mirage theme for iTerm2 downloaded. Please, install manually."

# Download Firacode Nerd Fonts
curl -o https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/EnvyCodeR.zip
echo "Nerd Fonts downloaded. Please, install manually"

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

# Move configurations from ./fish to ~/.config/fish
echo "Moving fish configurations..."
mkdir -p ~/.config/fish
cp ./fish/config.fish ~/.config/fish/

# configure fish as default shell
echo "Configuring fish as default shell..."
sudo sh -c 'echo /opt/homebrew/bin/fish >> /etc/shells'
chsh -s /opt/homebrew/bin/fish

# Check if we have nvm installed
# If not, install it
if command -v nvm &> /dev/null 2>&1; then
    echo "NVM found."
else
    fisher install jorgebucaran/nvm.fish
    nvm install 20
fi

echo "Installing neovim plugins"
nvim -c 'PluginInstall' -c 'qa!'

# Install CoC for nvim
echo "Installing CoC"
cd ~/.vim/bundle/coc.nvim/ && npm ci

